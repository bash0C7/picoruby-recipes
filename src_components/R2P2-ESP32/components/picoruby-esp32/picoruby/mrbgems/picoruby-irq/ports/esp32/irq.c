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
  int last_gpio_level;  /* Track previous GPIO state for edge detection */
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
  uint32_t current_time = esp_timer_get_time() / 1000;  /* Convert to milliseconds */

  if (!handler || !handler->enabled) {
    return;
  }

  /* Get current GPIO state */
  int current_level = gpio_get_level(handler->pin);
  int previous_level = handler->last_gpio_level;

  /* Determine edge direction by comparing with previous state */
  uint32_t events;
  if (previous_level == 1 && current_level == 0) {
    events = 4; /* EDGE_FALL (HIGH → LOW) */
  } else if (previous_level == 0 && current_level == 1) {
    events = 8; /* EDGE_RISE (LOW → HIGH) */
  } else {
    /* No state change (chattering, noise, or level interrupt) */
    /* For level interrupts, event_mask contains LEVEL_LOW/HIGH */
    if (current_level == 0 && (handler->event_mask & 1)) {
      events = 1; /* LEVEL_LOW */
    } else if (current_level == 1 && (handler->event_mask & 2)) {
      events = 2; /* LEVEL_HIGH */
    } else {
      return;  /* Ignore */
    }
  }

  /* Same logic as RP2040: filter by event_mask */
  if (!(events & handler->event_mask)) {
    return;  /* Handler not interested in this event */
  }

  /* Check debounce */
  if (handler->debounce_ms > 0) {
    uint32_t time_diff = (current_time - handler->last_event_time) & 0xFFFFFFFF;
    if (time_diff < handler->debounce_ms && 
        events == handler->last_event_type) {
      return;  /* Skip due to debounce */
    }
  }

  /* Update event history */
  handler->last_event_time = current_time;
  handler->last_event_type = events;
  handler->last_gpio_level = current_level;  /* Update state */

  /* Same logic as RP2040: calculate IRQ ID from handler index */
  int irq_id = -1;
  for (int i = 0; i < MAX_IRQ_HANDLERS; i++) {
    if (&irq_handlers[i] == handler) {
      irq_id = i + 1;  /* 1-based ID */
      break;
    }
  }

  if (irq_id < 0) return;

  /* Same logic as RP2040: add event to queue */
  irq_event_t event = {
    .irq_id = irq_id,
    .event_type = events
  };

  xQueueSendFromISR(event_queue, &event, NULL);
}

int
IRQ_register_gpio(int pin, int event_type, uint32_t debounce_ms)
{
  /* Find free slot */
  int slot = -1;
  for (int i = 0; i < MAX_IRQ_HANDLERS; i++) {
    if (!irq_handlers[i].enabled) {
      slot = i;
      break;
    }
  }

  if (slot < 0) {
    return -1;  /* No free slots */
  }

  /* Same logic as RP2040: convert event_type to event_mask */
  uint32_t event_mask = 0;
  if (event_type & 1) event_mask |= 1;  /* LEVEL_LOW = 1 */
  if (event_type & 2) event_mask |= 2;  /* LEVEL_HIGH = 2 */
  if (event_type & 4) event_mask |= 4;  /* EDGE_FALL = 4 */
  if (event_type & 8) event_mask |= 8;  /* EDGE_RISE = 8 */

  /* Initialize queue and ISR service on first use */
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

  /* Configure GPIO */
  gpio_config_t io_conf = {
    .pin_bit_mask = (1ULL << pin),
    .mode = GPIO_MODE_INPUT,
    .pull_up_en = GPIO_PULLUP_DISABLE,
    .pull_down_en = GPIO_PULLDOWN_DISABLE,
    .intr_type = GPIO_INTR_DISABLE  /* Start with interrupts disabled */
  };

  esp_err_t ret = gpio_config(&io_conf);
  if (ret != ESP_OK) {
    return -1;
  }

  vTaskDelay(pdMS_TO_TICKS(10));  /* 10ms stabilization time */

  /* Set interrupt type
   * 
   * For EDGE_FALL | EDGE_RISE, use GPIO_INTR_ANYEDGE
   * Determine FALL/RISE in ISR by comparing with previous state
   */
  gpio_int_type_t intr_type = GPIO_INTR_DISABLE;
  
  if ((event_type & 4) && (event_type & 8)) {
    /* Both edges specified */
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

  gpio_intr_disable(pin);  /* Ensure disabled first */
  
  int initial_level = gpio_get_level(pin);
  
  /* Store handler info */
  irq_handlers[slot].pin = pin;
  irq_handlers[slot].event_mask = event_mask;
  irq_handlers[slot].enabled = true;
  irq_handlers[slot].debounce_ms = debounce_ms;
  irq_handlers[slot].last_event_time = 0;
  irq_handlers[slot].last_event_type = 0;
  irq_handlers[slot].last_gpio_level = initial_level;  /* Use stable initial state */

  /* Add ISR handler */
  ret = gpio_isr_handler_add(pin, gpio_isr_handler, &irq_handlers[slot]);
  if (ret != ESP_OK) {
    irq_handlers[slot].enabled = false;
    return -1;
  }

  irq_event_t dummy_event;
  while (xQueueReceive(event_queue, &dummy_event, 0) == pdTRUE) {
    /* Drain queue */
  }

  ret = gpio_intr_enable(pin);
  if (ret != ESP_OK) {
    gpio_isr_handler_remove(pin);
    irq_handlers[slot].enabled = false;
    return -1;
  }

  return slot + 1;  /* Return 1-based ID */
}

bool
IRQ_unregister_gpio(int irq_id)
{
  int slot = irq_id - 1;  /* Convert to 0-based index */

  if (slot < 0 || slot >= MAX_IRQ_HANDLERS || !irq_handlers[slot].enabled) {
    return false;  /* Invalid ID or not registered */
  }

  bool prev_state = irq_handlers[slot].enabled;

  /* Disable GPIO IRQ */
  gpio_isr_handler_remove(irq_handlers[slot].pin);
  gpio_set_intr_type(irq_handlers[slot].pin, GPIO_INTR_DISABLE);

  /* Clear handler */
  memset(&irq_handlers[slot], 0, sizeof(mrb_irq_handler_t));

  return prev_state;
}

bool
IRQ_peek_event(int *irq_id, int *event_type)
{
  if (event_queue == NULL) {
    return false;  /* Queue not initialized */
  }

  irq_event_t event;
  if (xQueueReceive(event_queue, &event, 0) == pdTRUE) {
    *irq_id = event.irq_id;
    *event_type = event.event_type;
    return true;
  }

  return false;  /* Queue empty */
}

void
IRQ_init(void)
{
  /* Initialize data structures */
  memset(irq_handlers, 0, sizeof(irq_handlers));
}