#include <stdint.h>
#include <stdbool.h>
#include <string.h>

/* ESP-IDF includes */
#include "freertos/FreeRTOS.h"
#include "freertos/queue.h"
#include "driver/gpio.h"
#include "esp_log.h"
#include "esp_timer.h"

#include "../../include/irq.h"

/* 最大ハンドラ数とキューサイズ */
#define MAX_IRQ_HANDLERS 16
#define IRQ_EVENT_QUEUE_SIZE (1<<5)

/* IRQハンドラ情報 */
typedef struct {
  int pin;                    // GPIO番号
  uint32_t event_mask;        // イベントマスク
  bool enabled;               // 有効フラグ
  uint32_t debounce_ms;       // デバウンス時間（ミリ秒）
  uint32_t last_event_time;   // 最後のイベント時刻
  uint32_t last_event_type;   // 最後のイベントタイプ
} mrb_irq_handler_t;

/* イベントキューのデータ */
typedef struct {
  int irq_id;        // IRQ ID
  int event_type;    // イベントタイプ（1,2,4,8）
} irq_event_t;

/* グローバル変数 */
static mrb_irq_handler_t irq_handlers[MAX_IRQ_HANDLERS];
static QueueHandle_t event_queue = NULL;
static int next_irq_id = 1;
static bool isr_service_installed = false;

/* 
 * GPIO割り込みハンドラ（各GPIOから呼ばれる）
 * 引数argにはhandler構造体のポインタが渡される
 */
static void IRAM_ATTR gpio_isr_handler(void* arg)
{
  mrb_irq_handler_t* handler = (mrb_irq_handler_t*)arg;

  // ハンドラが無効な場合は何もしない
  if (!handler || !handler->enabled) {
    return;
  }

  /*
   * esp_timer_get_time(): ESP32のマイクロ秒単位のタイマー取得
   * 1000で割ってミリ秒に変換
   */
  uint32_t current_time = esp_timer_get_time() / 1000;

  /*
   * gpio_get_level(): 指定されたGPIOピンの現在の電気的レベルを取得
   * 戻り値: 0（LOW）または 1（HIGH）
   */
  int gpio_level = gpio_get_level(handler->pin);

  // 現在のレベルからイベントタイプを決定
  uint32_t events;
  if (gpio_level == 0) {
    events = 4; // EDGE_FALL と仮定
  } else {
    events = 8; // EDGE_RISE と仮定
  }

  // マスクされたイベントかチェック
  if (!(events & handler->event_mask)) {
    return;
  }

  // デバウンス処理
  if (handler->debounce_ms > 0) {
    uint32_t time_diff = (current_time - handler->last_event_time) & 0xFFFFFFFF;
    if (time_diff < handler->debounce_ms &&
        events == handler->last_event_type) {
      return; // デバウンス期間中なので無視
    }
  }

  // イベント履歴を更新
  handler->last_event_time = current_time;
  handler->last_event_type = events;

  // IRQ IDを計算（配列インデックス+1）
  int irq_id = -1;
  for (int i = 0; i < MAX_IRQ_HANDLERS; i++) {
    if (&irq_handlers[i] == handler) {
      irq_id = i + 1;
      break;
    }
  }

  if (irq_id < 0) return;

  // イベントをキューに追加
  irq_event_t event = {
    .irq_id = irq_id,
    .event_type = events
  };

  /*
   * xQueueSendFromISR(): 割り込みハンドラからFreeRTOSキューにデータを送信
   * 第1引数: キューハンドル
   * 第2引数: 送信するデータのポインタ
   * 第3引数: 高優先度タスクが起きたかのフラグ（NULLで無視）
   * 戻り値: pdTRUE（成功）またはpdFALSE（失敗）
   */
  xQueueSendFromISR(event_queue, &event, NULL);
}

/*
 * PicoRubyのイベントタイプをESP32のGPIO割り込みタイプに変換
 * PicoRubyの定義:
 * LEVEL_LOW = 1, LEVEL_HIGH = 2, EDGE_FALL = 4, EDGE_RISE = 8
 */
static gpio_int_type_t convert_event_type(int event_type)
{
  // 最初に見つかったイベントタイプで設定（シンプル版）
  if (event_type & 4) return GPIO_INTR_NEGEDGE;   // EDGE_FALL
  if (event_type & 8) return GPIO_INTR_POSEDGE;   // EDGE_RISE  
  if (event_type & 1) return GPIO_INTR_LOW_LEVEL; // LEVEL_LOW
  if (event_type & 2) return GPIO_INTR_HIGH_LEVEL; // LEVEL_HIGH
  
  return GPIO_INTR_DISABLE;
}

/* GPIO IRQを登録する */
int IRQ_register_gpio(int pin, int event_type, uint32_t debounce_ms)
{
  // 空きスロットを探す
  int slot = -1;
  for (int i = 0; i < MAX_IRQ_HANDLERS; i++) {
    if (!irq_handlers[i].enabled) {
      slot = i;
      break;
    }
  }

  if (slot < 0) {
    return -1; // 空きスロットなし
  }

  // event_typeをevent_maskに変換
  uint32_t event_mask = 0;
  if (event_type & 1) event_mask |= GPIO_INTR_LOW_LEVEL;  // LEVEL_LOW = 1
  if (event_type & 2) event_mask |= GPIO_INTR_HIGH_LEVEL; // LEVEL_HIGH = 2
  if (event_type & 4) event_mask |= GPIO_INTR_NEGEDGE;    // EDGE_FALL = 4
  if (event_type & 8) event_mask |= GPIO_INTR_POSEDGE;    // EDGE_RISE = 8

  /*
   * 初回のみFreeRTOSキューとGPIO ISRサービスを初期化
   */
  if (event_queue == NULL) {
    /*
     * xQueueCreate(): FreeRTOSキューを作成
     * 第1引数: キューが保持できる項目数
     * 第2引数: 各項目のサイズ（バイト）
     * 戻り値: キューハンドル（失敗時NULL）
     */
    event_queue = xQueueCreate(IRQ_EVENT_QUEUE_SIZE, sizeof(irq_event_t));
    if (event_queue == NULL) {
      return -1;
    }
  }

  if (!isr_service_installed) {
    /*
     * gpio_install_isr_service(): GPIO割り込みサービスをインストール
     * ESP32では全GPIOで共有される割り込みサービスを初期化する
     * 引数: 割り込み割り当てフラグ（0で自動割り当て）
     * 戻り値: ESP_OK（成功）またはエラーコード
     */
    esp_err_t ret = gpio_install_isr_service(0);
    if (ret != ESP_OK && ret != ESP_ERR_INVALID_STATE) {
      return -1;
    }
    isr_service_installed = true;
  }

  /*
   * GPIO設定構造体の準備
   * gpio_config_t: GPIOの入出力方向、プルアップ/ダウン、割り込みタイプを設定
   */
  gpio_config_t io_conf = {
    .pin_bit_mask = (1ULL << pin),                    // 設定するピンのビットマスク
    .mode = GPIO_MODE_INPUT,                          // 入力モード
    .pull_up_en = GPIO_PULLUP_DISABLE,               // プルアップ無効
    .pull_down_en = GPIO_PULLDOWN_DISABLE,           // プルダウン無効
    .intr_type = convert_event_type(event_type)       // 割り込みタイプ
  };

  /*
   * gpio_config(): GPIO設定を適用
   * 引数: gpio_config_t構造体のポインタ
   * 戻り値: ESP_OK（成功）またはエラーコード
   */
  esp_err_t ret = gpio_config(&io_conf);
  if (ret != ESP_OK) {
    return -1;
  }

  // ハンドラ情報を設定
  irq_handlers[slot].pin = pin;
  irq_handlers[slot].event_mask = event_mask;
  irq_handlers[slot].enabled = true;
  irq_handlers[slot].debounce_ms = debounce_ms;
  irq_handlers[slot].last_event_time = 0;
  irq_handlers[slot].last_event_type = 0;

  /*
   * gpio_isr_handler_add(): 指定GPIOに割り込みハンドラを追加
   * 第1引数: GPIO番号
   * 第2引数: 割り込みハンドラ関数のポインタ
   * 第3引数: ハンドラに渡される引数（void*）
   * 戻り値: ESP_OK（成功）またはエラーコード
   */
  ret = gpio_isr_handler_add(pin, gpio_isr_handler, &irq_handlers[slot]);
  if (ret != ESP_OK) {
    irq_handlers[slot].enabled = false;
    return -1;
  }

  return slot + 1; // 1ベースのIDを返す
}

/* GPIO IRQの登録を解除する */
bool IRQ_unregister_gpio(int irq_id)
{
  int slot = irq_id - 1; // 0ベースのインデックスに変換

  if (slot < 0 || slot >= MAX_IRQ_HANDLERS || !irq_handlers[slot].enabled) {
    return false; // 無効なIDまたは未登録
  }

  bool prev_state = irq_handlers[slot].enabled;

  /*
   * gpio_isr_handler_remove(): 指定GPIOの割り込みハンドラを削除
   * 引数: GPIO番号
   * 戻り値: ESP_OK（成功）またはエラーコード
   */
  gpio_isr_handler_remove(irq_handlers[slot].pin);

  /*
   * gpio_set_intr_type(): GPIO割り込みタイプを設定
   * 第1引数: GPIO番号
   * 第2引数: 割り込みタイプ（GPIO_INTR_DISABLEで無効化）
   */
  gpio_set_intr_type(irq_handlers[slot].pin, GPIO_INTR_DISABLE);

  // ハンドラをクリア
  memset(&irq_handlers[slot], 0, sizeof(mrb_irq_handler_t));

  return prev_state;
}

/* イベントキューから1つのイベントを取得する */
bool IRQ_peek_event(int *irq_id, int *event_type)
{
  if (event_queue == NULL) {
    return false;
  }
  
  irq_event_t event;
  /*
   * xQueueReceive(): FreeRTOSキューからデータを受信
   * 第1引数: キューハンドル
   * 第2引数: 受信データを格納するバッファ
   * 第3引数: 待機時間（0は待機しない）
   * 戻り値: pdTRUE（成功）またはpdFALSE（失敗/タイムアウト）
   */
  if (xQueueReceive(event_queue, &event, 0) == pdTRUE) {
    *irq_id = event.irq_id;
    *event_type = event.event_type;
    return true;
  }
  
  return false; // キューが空
}

/* IRQサブシステムを初期化する */
void IRQ_init(void)
{
  // データ構造を初期化
  memset(irq_handlers, 0, sizeof(irq_handlers));
  next_irq_id = 1;

  // キューとISRサービスは最初のregister時に初期化（遅延初期化）
}
