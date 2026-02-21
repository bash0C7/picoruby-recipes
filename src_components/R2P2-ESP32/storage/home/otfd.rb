# フィンガードラム装置（Chain DualKey用、完全手動モード、IRQ方式）
DEBUG = false  # デバッグモード

require 'ws2812'
require 'gpio'
require 'irq'
require 'uart'

class FingerDrum
  MIDI_TX_PIN = 6
  MIDI_RX_PIN = 5

  # ボタン → ドラム音マッピング
  BUTTON_PINS = {
    17 => 36,  # GPIO17(KEY1) → KICK (36)
    0 => 38    # GPIO0(KEY2) → SNARE (38)
  }

  def initialize(uart)
    @uart = uart
  end

  def play_note(pin)
    note = BUTTON_PINS[pin]
    @uart.write((0x99).chr + note.chr + (0x7F).chr)
    puts "Button #{pin} pressed → Note #{note}" if DEBUG
  end
end

class DualKeyLED
  LED_PIN = 21
  LED_COUNT = 2

  # ボタン → RGB色マッピング（フラッシュ時の最大輝度版）
  FLASH_COLORS = {
    17 => {r: 255, g: 0, b: 0},      # KICK → 鮮やかな赤
    0 => {r: 0, g: 255, b: 255}      # SNARE → 鮮やかなシアン
  }

  # アイドル時のグレー色（電源ON表示）
  IDLE_R = 5
  IDLE_G = 5
  IDLE_B = 5

  def initialize(led_strip)
    @led_strip = led_strip
    @led_colors = Array.new(LED_COUNT, [IDLE_R, IDLE_G, IDLE_B])
  end

  def flash(pin)
    # 押下瞬間のフラッシュ（最大輝度・明度）
    color = FLASH_COLORS[pin]
    LED_COUNT.times do |i|
      @led_colors[i] = [color[:r], color[:g], color[:b]]
    end
    @led_strip.show_rgb(*@led_colors)
  end

  def show_idle
    # アイドル状態（うっすらグレー）
    LED_COUNT.times do |i|
      @led_colors[i] = [IDLE_R, IDLE_G, IDLE_B]
    end
    @led_strip.show_rgb(*@led_colors)
  end
end

# MIDI初期化（Chain Bus左側: GPIO6/GPIO5 = UART2）
md_uart = UART.new(unit: :ESP32_UART2, baudrate: 31250, txd_pin: FingerDrum::MIDI_TX_PIN, rxd_pin: FingerDrum::MIDI_RX_PIN)
sleep_ms(10)
md_uart.clear_rx_buffer

# WS2812B電源制御（GPIO40をON）
led_power = GPIO.new(40, GPIO::OUT)
led_power.write(1)
sleep_ms(10)

# 内蔵LED初期化
led_strip = WS2812.new(RMTDriver.new(DualKeyLED::LED_PIN))

# 装置初期化
drum = FingerDrum.new(md_uart)
led = DualKeyLED.new(led_strip)

# 2つのボタンを個別に生成
button_17 = GPIO.new(17, GPIO::IN|GPIO::PULL_UP)
button_0 = GPIO.new(0, GPIO::IN|GPIO::PULL_UP)

# GPIO17 IRQ登録（バスドラム）
irq_17 = button_17.irq(GPIO::EDGE_FALL, debounce: 150,
                       capture: {drum: drum, led: led, pin: 17}) do |btn, ev, cap|
  cap[:drum].play_note(cap[:pin])
  cap[:led].flash(cap[:pin])
end

# GPIO0 IRQ登録（スネア）※注意: GPIO0はブートピン
irq_0 = button_0.irq(GPIO::EDGE_FALL, debounce: 150,
                     capture: {drum: drum, led: led, pin: 0}) do |btn, ev, cap|
  cap[:drum].play_note(cap[:pin])
  cap[:led].flash(cap[:pin])
end

# メインループ
loop_counter = 0
loop do
  IRQ.process

  # LED常時アイドル表示（うっすらグレー、10msごとに更新）
  if loop_counter % 5 == 0
    led.show_idle
  end

  loop_counter += 1
  sleep_ms(2)
end

# 終了時に全IRQ解除
irq_17.unregister
irq_0.unregister
