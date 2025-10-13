#include <stdint.h>
#include <string.h>
#include "freertos/FreeRTOS.h"
#include "freertos/queue.h"
#include "driver/gpio.h"
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
  int last_gpio_level;
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
  int previous_level = handler->last_gpio_level;
  
  /* 状態更新（エッジ判定に必要） */
  handler->last_gpio_level = current_level;

  /* イベントタイプ判定 */
  uint32_t events = 0;
  
  if (previous_level == 1 && current_level == 0) {
    events = 4;  /* EDGE_FALL */
  } else if (previous_level == 0 && current_level == 1) {
    events = 8;  /* EDGE_RISE */
  } else if (current_level == 0) {
    events = 1;  /* LEVEL_LOW */
  } else {
    events = 2;  /* LEVEL_HIGH */
  }

  /* イベントマスクでフィルタ */
  if (!(events & handler->event_mask)) {
    return;
  }

  /* デバウンス処理 */
  if (handler->debounce_ms > 0) {
    uint32_t time_diff = (current_time - handler->last_event_time) & 0xFFFFFFFF;
    if (time_diff < handler->debounce_ms && events == handler->last_event_type) {
      return;
    }
  }

  /* イベント履歴更新 */
  handler->last_event_time = current_time;
  handler->last_event_type = events;

  /* IRQ ID計算（ポインタ演算） */
  int slot = handler - irq_handlers;
  int irq_id = slot + 1;

  /* イベントキューイング */
  irq_event_t event = {
    .irq_id = irq_id,
    .event_type = events
  };

  /* キュー満杯時はイベント破棄（RP2040と同じ挙動） */
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

  /* event_typeをevent_maskに変換 */
  uint32_t event_mask = 0;
  if (event_type & 1) event_mask |= 1;  /* LEVEL_LOW */
  if (event_type & 2) event_mask |= 2;  /* LEVEL_HIGH */
  if (event_type & 4) event_mask |= 4;  /* EDGE_FALL */
  if (event_type & 8) event_mask |= 8;  /* EDGE_RISE */

  /* イベントキュー初期化 */
  if (event_queue == NULL) {
    event_queue = xQueueCreate(IRQ_EVENT_QUEUE_SIZE, sizeof(irq_event_t));
    if (event_queue == NULL) {
      return -1;
    }
  }

  /* ISRサービスインストール */
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

  /* GPIO安定化待機 */
  vTaskDelay(pdMS_TO_TICKS(10));

  /* 割り込みタイプ決定（エッジ優先） */
  gpio_int_type_t intr_type;
  
  if ((event_type & 0xC) != 0) {
    /* EDGE_FALL(4) または EDGE_RISE(8) が含まれる */
    intr_type = GPIO_INTR_ANYEDGE;
  } else if ((event_type & 0x3) == 0x3) {
    /* LEVEL_LOW(1) + LEVEL_HIGH(2) → ANYEDGE扱い */
    intr_type = GPIO_INTR_ANYEDGE;
  } else if (event_type & 1) {
    intr_type = GPIO_INTR_LOW_LEVEL;
  } else if (event_type & 2) {
    intr_type = GPIO_INTR_HIGH_LEVEL;
  } else {
    return -1;  /* 到達しないはずだが念のため */
  }

  ret = gpio_set_intr_type(pin, intr_type);
  if (ret != ESP_OK) {
    return -1;
  }

  /* 初期状態読み取り */
  int initial_level = gpio_get_level(pin);

  /* ハンドラ情報保存 */
  irq_handlers[slot].pin = pin;
  irq_handlers[slot].event_mask = event_mask;
  irq_handlers[slot].enabled = true;
  irq_handlers[slot].debounce_ms = debounce_ms;
  irq_handlers[slot].last_event_time = 0;
  irq_handlers[slot].last_event_type = 0;
  irq_handlers[slot].last_gpio_level = initial_level;

  /* ISRハンドラ追加 */
  ret = gpio_isr_handler_add(pin, gpio_isr_handler, &irq_handlers[slot]);
  if (ret != ESP_OK) {
    irq_handlers[slot].enabled = false;
    return -1;
  }

  /* イベントキュークリア */
  irq_event_t dummy_event;
  while (xQueueReceive(event_queue, &dummy_event, 0) == pdTRUE) {
    /* キュー空にする */
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

  /* GPIO割り込み無効化 */
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