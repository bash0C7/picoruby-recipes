#include <stdint.h>
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
  uint32_t event_mask;           /* ユーザーが要求したイベントタイプ */
  bool enabled;
  uint32_t debounce_ms;
  uint32_t last_event_time;
  uint32_t last_event_type;
  gpio_int_type_t current_intr_type;  /* 現在設定されている割り込みタイプ */
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
 * すべての割り込みをLOW_LEVEL/HIGH_LEVELの切り替えで実装
 */
static void IRAM_ATTR
gpio_isr_handler(void* arg)
{
  mrb_irq_handler_t* handler = (mrb_irq_handler_t*)arg;
  uint32_t current_time = esp_timer_get_time() / 1000;

  if (!handler || !handler->enabled) {
    return;
  }

  /* 現在のGPIOレベルを読む */
  int current_level = gpio_get_level(handler->pin);

  /* 
   * 現在のレベルに基づいてイベントタイプを決定
   * LOW_LEVEL割り込みが発火 → ピンはLOW → LEVEL_LOWまたはEDGE_FALL
   * HIGH_LEVEL割り込みが発火 → ピンはHIGH → LEVEL_HIGHまたはEDGE_RISE
   */
  uint32_t events;
  if (current_level == 0) {
    /* ピンがLOW */
    if (handler->event_mask & 1) {
      events = 1;  /* LEVEL_LOW */
    } else if (handler->event_mask & 4) {
      events = 4;  /* EDGE_FALL */
    } else {
      /* このレベルには興味がない */
      gpio_set_intr_type(handler->pin, GPIO_INTR_HIGH_LEVEL);
      return;
    }
  } else {
    /* ピンがHIGH */
    if (handler->event_mask & 2) {
      events = 2;  /* LEVEL_HIGH */
    } else if (handler->event_mask & 8) {
      events = 8;  /* EDGE_RISE */
    } else {
      /* このレベルには興味がない */
      gpio_set_intr_type(handler->pin, GPIO_INTR_LOW_LEVEL);
      return;
    }
  }

  /* デバウンスチェック */
  if (handler->debounce_ms > 0) {
    uint32_t time_diff = (current_time - handler->last_event_time) & 0xFFFFFFFF;
    if (time_diff < handler->debounce_ms && 
        events == handler->last_event_type) {
      /* デバウンス期間中：次の状態に切り替えて終了 */
      if (current_level == 0) {
        gpio_set_intr_type(handler->pin, GPIO_INTR_HIGH_LEVEL);
      } else {
        gpio_set_intr_type(handler->pin, GPIO_INTR_LOW_LEVEL);
      }
      return;
    }
  }

  /* イベント履歴を更新 */
  handler->last_event_time = current_time;
  handler->last_event_type = events;

  /* 次の状態に切り替え（状態マシンの核心） */
  if (current_level == 0) {
    /* 現在LOW → 次はHIGHを監視 */
    gpio_set_intr_type(handler->pin, GPIO_INTR_HIGH_LEVEL);
    handler->current_intr_type = GPIO_INTR_HIGH_LEVEL;
  } else {
    /* 現在HIGH → 次はLOWを監視 */
    gpio_set_intr_type(handler->pin, GPIO_INTR_LOW_LEVEL);
    handler->current_intr_type = GPIO_INTR_LOW_LEVEL;
  }

  /* IRQ IDを計算 */
  int irq_id = -1;
  for (int i = 0; i < MAX_IRQ_HANDLERS; i++) {
    if (&irq_handlers[i] == handler) {
      irq_id = i + 1;
      break;
    }
  }

  if (irq_id < 0) return;
   
  /* イベントをキューに追加 */
  irq_event_t event = {
    .irq_id = irq_id,
    .event_type = events
  };

  BaseType_t ret = xQueueSendFromISR(event_queue, &event, NULL);
  if (ret != pdPASS) {
    /* キューが満杯の場合はイベントを破棄 */
  }
}

int
IRQ_register_gpio(int pin, int event_type, uint32_t debounce_ms)
{
  /* 空きスロットを探す */
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

  /* event_typeをevent_maskに変換 */
  uint32_t event_mask = 0;
  if (event_type & 1) event_mask |= 1;  /* LEVEL_LOW */
  if (event_type & 2) event_mask |= 2;  /* LEVEL_HIGH */
  if (event_type & 4) event_mask |= 4;  /* EDGE_FALL */
  if (event_type & 8) event_mask |= 8;  /* EDGE_RISE */

  /* キューとISRサービスの初期化 */
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

  vTaskDelay(pdMS_TO_TICKS(10));  /* 安定化時間 */

  /* 
   * 状態マシンの初期設定：現在のピンレベルに基づく
   * - ピンがLOWなら、最初はHIGH_LEVELを監視（次の遷移を待つ）
   * - ピンがHIGHなら、最初はLOW_LEVELを監視（次の遷移を待つ）
   */
  int initial_level = gpio_get_level(pin);
  gpio_int_type_t intr_type = (initial_level == 0) ? GPIO_INTR_HIGH_LEVEL : GPIO_INTR_LOW_LEVEL;

  ret = gpio_set_intr_type(pin, intr_type);
  if (ret != ESP_OK) {
    return -1;
  }

  /* ハンドラ情報を保存 */
  irq_handlers[slot].pin = pin;
  irq_handlers[slot].event_mask = event_mask;
  irq_handlers[slot].enabled = true;
  irq_handlers[slot].debounce_ms = debounce_ms;
  irq_handlers[slot].last_event_time = 0;
  irq_handlers[slot].last_event_type = 0;
  irq_handlers[slot].current_intr_type = intr_type;

  /* ISRハンドラを追加 */
  ret = gpio_isr_handler_add(pin, gpio_isr_handler, &irq_handlers[slot]);
  if (ret != ESP_OK) {
    irq_handlers[slot].enabled = false;
    return -1;
  }

  /* キューをクリア */
  irq_event_t dummy_event;
  while (xQueueReceive(event_queue, &dummy_event, 0) == pdTRUE) {
    /* 既存のイベントをクリア */
  }

  /* 割り込みを有効化 */
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

  /* GPIO割り込みを無効化 */
  gpio_isr_handler_remove(irq_handlers[slot].pin);
  gpio_set_intr_type(irq_handlers[slot].pin, GPIO_INTR_DISABLE);

  /* ハンドラをクリア */
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