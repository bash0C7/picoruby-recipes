#include <stdint.h>
#include <string.h>
#include "freertos/FreeRTOS.h"
#include "freertos/queue.h"
#include "driver/gpio.h"
#include "esp_timer.h"

#include "../../include/irq.h"

#define MAX_IRQ_HANDLERS 16
#define IRQ_EVENT_QUEUE_SIZE (1<<5)

/*
 * ESP32実装の設計方針
 * 
 * 割り込みライブラリの責務：
 * - 割り込みタイプの設定（gpio_set_intr_type）
 * - ISRハンドラの登録（gpio_isr_handler_add）
 * - 割り込みの有効化/無効化（gpio_intr_enable/disable）
 * 
 * アプリケーションの責務：
 * - GPIO方向の設定（INPUT/OUTPUT）
 * - プルアップ/プルダウンの設定
 * - 初期レベルの設定
 * 
 * 境界を守ることで、アプリケーション側のGPIO設定を尊重する。
 */

typedef struct {
  int pin;
  uint32_t event_mask;
  bool enabled;
  uint32_t debounce_ms;
  uint32_t last_event_time;
  uint32_t last_event_type;
} mrb_irq_handler_t;

typedef struct {
  int irq_id;
  int event_type;
} irq_event_t;

static mrb_irq_handler_t irq_handlers[MAX_IRQ_HANDLERS];
static QueueHandle_t event_queue = NULL;
static bool isr_service_installed = false;

/*
 * GPIO ISR Handler（統一状態マシン方式）
 */
static void IRAM_ATTR
gpio_isr_handler(void* arg)
{
  mrb_irq_handler_t* handler = (mrb_irq_handler_t*)arg;
  
  if (!handler || !handler->enabled) {
    return;
  }

  uint32_t current_time = esp_timer_get_time() / 1000;
  int current_level = gpio_get_level(handler->pin);

  /* イベントタイプ決定（EDGE優先） */
  uint32_t events;
  gpio_int_type_t next_intr_type;
  
  if (current_level == 0) {
    /* ピンがLOW */
    if (handler->event_mask & 4) {
      events = 4;  /* EDGE_FALL */
    } else if (handler->event_mask & 1) {
      events = 1;  /* LEVEL_LOW */
    } else {
      gpio_set_intr_type(handler->pin, GPIO_INTR_HIGH_LEVEL);
      return;
    }
    next_intr_type = GPIO_INTR_HIGH_LEVEL;
  } else {
    /* ピンがHIGH */
    if (handler->event_mask & 8) {
      events = 8;  /* EDGE_RISE */
    } else if (handler->event_mask & 2) {
      events = 2;  /* LEVEL_HIGH */
    } else {
      gpio_set_intr_type(handler->pin, GPIO_INTR_LOW_LEVEL);
      return;
    }
    next_intr_type = GPIO_INTR_LOW_LEVEL;
  }

  /* デバウンスチェック */
  if (handler->debounce_ms > 0) {
    uint32_t time_diff = (current_time - handler->last_event_time) & 0xFFFFFFFF;
    if (time_diff < handler->debounce_ms && events == handler->last_event_type) {
      gpio_set_intr_type(handler->pin, next_intr_type);
      return;
    }
  }

  /* イベント履歴更新 */
  handler->last_event_time = current_time;
  handler->last_event_type = events;

  /* 状態マシン：次の状態に切り替え */
  gpio_set_intr_type(handler->pin, next_intr_type);

  /* IRQ ID計算 */
  int irq_id = (handler - irq_handlers) + 1;

  /* イベントキューイング */
  irq_event_t event = {
    .irq_id = irq_id,
    .event_type = events
  };

  xQueueSendFromISR(event_queue, &event, NULL);
}

int
IRQ_register_gpio(int pin, int event_type, uint32_t debounce_ms)
{
  /* 空きスロット検索 */
  int slot = -1;
  for (int i = 0; i < MAX_IRQ_HANDLERS; i++) {
    if (!irq_handlers[i].enabled) {
      slot = i;
      break;
    }
  }

  if (slot < 0) {
    return -1;
  }

  /* event_maskに変換 */
  uint32_t event_mask = event_type & 0xF;

  /* キュー初期化（初回のみ） */
  if (event_queue == NULL) {
    event_queue = xQueueCreate(IRQ_EVENT_QUEUE_SIZE, sizeof(irq_event_t));
    if (event_queue == NULL) {
      return -1;
    }
  }

  /* ISRサービス初期化（初回のみ） */
  if (!isr_service_installed) {
    esp_err_t ret = gpio_install_isr_service(0);
    if (ret != ESP_OK && ret != ESP_ERR_INVALID_STATE) {
      return -1;
    }
    isr_service_installed = true;
  }

  /* 
   * ✅ 重要：アプリケーションのGPIO設定を尊重
   * 
   * gpio_config()は呼ばず、割り込み関連の設定のみを行う。
   * GPIO方向、プルアップ/ダウンはアプリケーション側で既に設定済み。
   */

  /* 現在のピンレベルを読む（アプリケーションの設定を前提） */
  int initial_level = gpio_get_level(pin);

  /* 状態マシン初期化：現在のピンレベルの逆を監視 */
  gpio_int_type_t intr_type = (initial_level == 0) ? 
    GPIO_INTR_HIGH_LEVEL : GPIO_INTR_LOW_LEVEL;

  esp_err_t ret = gpio_set_intr_type(pin, intr_type);
  if (ret != ESP_OK) {
    return -1;
  }

  /* ハンドラ情報保存 */
  irq_handlers[slot].pin = pin;
  irq_handlers[slot].event_mask = event_mask;
  irq_handlers[slot].enabled = true;
  irq_handlers[slot].debounce_ms = debounce_ms;
  irq_handlers[slot].last_event_time = 0;
  irq_handlers[slot].last_event_type = 0;

  /* ISRハンドラ登録 */
  ret = gpio_isr_handler_add(pin, gpio_isr_handler, &irq_handlers[slot]);
  if (ret != ESP_OK) {
    irq_handlers[slot].enabled = false;
    return -1;
  }

  /* イベントキュークリア */
  irq_event_t dummy_event;
  while (xQueueReceive(event_queue, &dummy_event, 0) == pdTRUE) {
    /* キューを空にする */
  }

  /* 割り込み有効化 */
  ret = gpio_intr_enable(pin);
  if (ret != ESP_OK) {
    gpio_isr_handler_remove(pin);
    irq_handlers[slot].enabled = false;
    return -1;
  }

  return slot + 1;
}

bool
IRQ_unregister_gpio(int irq_id)
{
  int slot = irq_id - 1;

  if (slot < 0 || slot >= MAX_IRQ_HANDLERS || !irq_handlers[slot].enabled) {
    return false;
  }

  bool prev_state = irq_handlers[slot].enabled;

  /* 割り込み関連の設定のみクリア（GPIO設定は保持） */
  gpio_isr_handler_remove(irq_handlers[slot].pin);
  gpio_set_intr_type(irq_handlers[slot].pin, GPIO_INTR_DISABLE);

  /* ハンドラクリア */
  memset(&irq_handlers[slot], 0, sizeof(mrb_irq_handler_t));

  return prev_state;
}

bool
IRQ_peek_event(int *irq_id, int *event_type)
{
  if (event_queue == NULL) {
    return false;
  }

  irq_event_t event;
  if (xQueueReceive(event_queue, &event, 0) == pdTRUE) {
    *irq_id = event.irq_id;
    *event_type = event.event_type;
    return true;
  }

  return false;
}

void
IRQ_init(void)
{
  memset(irq_handlers, 0, sizeof(irq_handlers));
}
