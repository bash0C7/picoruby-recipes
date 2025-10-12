/*
 * ESP32 GPIO IRQ Implementation
 * 
 * ⚠️ CRITICAL HARDWARE LIMITATIONS ⚠️
 * 
 * ESP32 has known hardware bugs with GPIO edge-triggered interrupts.
 * See: https://docs.espressif.com/projects/esp-chip-errata/en/latest/esp32/03-errata-description/esp32/gpio-edge-interrupts.html
 * 
 * Known Issues:
 * 1. Only ONE edge-triggered interrupt per GPIO group (GPIO0-31, GPIO32-39, RTC GPIO0-17)
 * 2. Edge interrupts may be lost during register operations
 * 3. Fast transitions (<2.5µs) may cause multiple ISR triggers or missed edges
 * 
 * Current Implementation:
 * - Tracks previous GPIO state to infer EDGE_FALL vs EDGE_RISE
 * - Works for most mechanical switches with debouncing
 * - May miss rapid transitions during interrupt latency
 * - Logic structure follows RP2040 port for consistency
 * 
 * Recommendations:
 * - Use only ONE edge interrupt per GPIO group
 * - Use debouncing (50-100ms) for mechanical switches
 * - For critical applications, implement level-trigger state machine (see Errata)
 */

#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include "freertos/FreeRTOS.h"
#include "freertos/queue.h"
#include "driver/gpio.h"
#include "esp_log.h"
#include "esp_timer.h"

#include "../../include/irq.h"

#define MAX_IRQ_HANDLERS 16
#define IRQ_EVENT_QUEUE_SIZE (1<<5)

typedef struct {
  int pin;
  uint32_t event_mask;
  bool enabled;
  uint32_t debounce_ms;
  uint32_t last_event_time;
  uint32_t last_event_type;
  int last_gpio_level;  /* 前回のGPIO状態（エッジ判定用） */
} mrb_irq_handler_t;

typedef struct {
  int irq_id;
  int event_type;
} irq_event_t;

static mrb_irq_handler_t irq_handlers[MAX_IRQ_HANDLERS];
static QueueHandle_t event_queue = NULL;
static bool isr_service_installed = false;

/*
 * GPIO ISR Handler
 * 
 * Edge Direction Detection Strategy:
 * 
 * Unlike RP2040 which provides accurate event information via callback parameter,
 * ESP32 does not tell us which edge triggered the interrupt when using ANYEDGE mode.
 * 
 * Solution: Track previous GPIO state and compare with current state
 * 
 * Example:
 *   Previous: HIGH, Current: LOW  → EDGE_FALL detected
 *   Previous: LOW,  Current: HIGH → EDGE_RISE detected
 * 
 * Limitation:
 *   If multiple edges occur during interrupt latency, only the last transition
 *   is detected. For mechanical switches with debouncing, this is acceptable.
 * 
 *   Example failure case (rare):
 *     Time 0: HIGH → LOW (FALL triggers interrupt)
 *     Time 1: LOW → HIGH (glitch during latency)
 *     Time 2: HIGH → LOW (another glitch)
 *     Time 3: ISR executes, sees LOW
 *     Result: Previous=HIGH, Current=LOW → FALL detected (correct by luck)
 *     But missed the intermediate RISE
 * 
 * This is a best-effort implementation given ESP32 hardware constraints.
 */
static void IRAM_ATTR
gpio_isr_handler(void* arg)
{
  mrb_irq_handler_t* handler = (mrb_irq_handler_t*)arg;
  uint32_t current_time = esp_timer_get_time() / 1000;  /* ミリ秒変換 */

  if (!handler || !handler->enabled) {
    return;
  }

  /* 現在のGPIO状態取得 */
  int current_level = gpio_get_level(handler->pin);
  int previous_level = handler->last_gpio_level;

  /* 前回状態と比較してエッジ方向判定 */
  uint32_t events;
  if (previous_level == 1 && current_level == 0) {
    events = 4; /* EDGE_FALL (HIGH → LOW) */
  } else if (previous_level == 0 && current_level == 1) {
    events = 8; /* EDGE_RISE (LOW → HIGH) */
  } else {
    /* 状態変化なし（チャタリング、ノイズ、レベル割り込み） */
    /* レベル割り込みの場合は event_mask が LEVEL_LOW/HIGH を含む */
    if (current_level == 0 && (handler->event_mask & 1)) {
      events = 1; /* LEVEL_LOW */
    } else if (current_level == 1 && (handler->event_mask & 2)) {
      events = 2; /* LEVEL_HIGH */
    } else {
      return;  /* 無視 */
    }
  }

  /* RP2040と同じロジック: event_maskでフィルタリング */
  if (!(events & handler->event_mask)) {
    return;  /* このハンドラが興味のないイベント */
  }

  /* デバウンス判定 */
  if (handler->debounce_ms > 0) {
    uint32_t time_diff = (current_time - handler->last_event_time) & 0xFFFFFFFF;
    if (time_diff < handler->debounce_ms && 
        events == handler->last_event_type) {
      return;  /* デバウンス中のためスキップ */
    }
  }

  /* イベント履歴更新 */
  handler->last_event_time = current_time;
  handler->last_event_type = events;
  handler->last_gpio_level = current_level;  /* 状態更新 */

  /* RP2040と同じロジック: ハンドラインデックスからIRQ ID計算 */
  int irq_id = -1;
  for (int i = 0; i < MAX_IRQ_HANDLERS; i++) {
    if (&irq_handlers[i] == handler) {
      irq_id = i + 1;  /* 1ベースのID */
      break;
    }
  }

  if (irq_id < 0) return;

  /* RP2040と同じロジック: イベントキュー追加 */
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
    return -1;  /* 空きスロットなし */
  }

  /* RP2040と同じロジック: event_typeをevent_maskに変換 */
  uint32_t event_mask = 0;
  if (event_type & 1) event_mask |= 1;  /* LEVEL_LOW = 1 */
  if (event_type & 2) event_mask |= 2;  /* LEVEL_HIGH = 2 */
  if (event_type & 4) event_mask |= 4;  /* EDGE_FALL = 4 */
  if (event_type & 8) event_mask |= 8;  /* EDGE_RISE = 8 */

  /* 初回使用時にキューとISRサービス初期化 */
  if (event_queue == NULL) {
    event_queue = xQueueCreate(IRQ_EVENT_QUEUE_SIZE, sizeof(irq_event_t));
    if (event_queue == NULL) {
      return -1;
    }
  }

  if (!isr_service_installed) {
    esp_err_t ret = gpio_install_isr_service(0);
    if (ret != ESP_OK && ret != ESP_ERR_INVALID_STATE) {
      return -1;
    }
    isr_service_installed = true;
  }

  /* GPIO設定 */
  gpio_config_t io_conf = {
    .pin_bit_mask = (1ULL << pin),
    .mode = GPIO_MODE_INPUT,
    .pull_up_en = GPIO_PULLUP_DISABLE,
    .pull_down_en = GPIO_PULLDOWN_DISABLE,
    .intr_type = GPIO_INTR_DISABLE
  };

  esp_err_t ret = gpio_config(&io_conf);
  if (ret != ESP_OK) {
    return -1;
  }

  /* 割り込みタイプ設定
   * 
   * EDGE_FALL | EDGE_RISE の場合は GPIO_INTR_ANYEDGE を使用
   * ISR内で前回状態と比較してFALL/RISEを判定
   */
  gpio_int_type_t intr_type = GPIO_INTR_DISABLE;
  
  if ((event_type & 4) && (event_type & 8)) {
    /* 両エッジ指定 */
    intr_type = GPIO_INTR_ANYEDGE;
  } else if (event_type & 4) {
    intr_type = GPIO_INTR_NEGEDGE;  /* EDGE_FALL */
  } else if (event_type & 8) {
    intr_type = GPIO_INTR_POSEDGE;  /* EDGE_RISE */
  } else if (event_type & 1) {
    intr_type = GPIO_INTR_LOW_LEVEL;  /* LEVEL_LOW */
  } else if (event_type & 2) {
    intr_type = GPIO_INTR_HIGH_LEVEL;  /* LEVEL_HIGH */
  }

  ret = gpio_set_intr_type(pin, intr_type);
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
  irq_handlers[slot].last_gpio_level = gpio_get_level(pin);  /* 初期状態記録 */

  /* ISRハンドラ追加 */
  ret = gpio_isr_handler_add(pin, gpio_isr_handler, &irq_handlers[slot]);
  if (ret != ESP_OK) {
    irq_handlers[slot].enabled = false;
    return -1;
  }

  return slot + 1;  /* 1ベースのID返却 */
}

bool
IRQ_unregister_gpio(int irq_id)
{
  int slot = irq_id - 1;  /* 0ベースインデックス変換 */

  if (slot < 0 || slot >= MAX_IRQ_HANDLERS || !irq_handlers[slot].enabled) {
    return false;  /* 無効なIDまたは未登録 */
  }

  bool prev_state = irq_handlers[slot].enabled;

  /* GPIO IRQ無効化 */
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
    return false;  /* キュー未初期化 */
  }

  irq_event_t event;
  if (xQueueReceive(event_queue, &event, 0) == pdTRUE) {
    *irq_id = event.irq_id;
    *event_type = event.event_type;
    return true;
  }

  return false;  /* キュー空 */
}

void
IRQ_init(void)
{
  /* データ構造初期化 */
  memset(irq_handlers, 0, sizeof(irq_handlers));
}