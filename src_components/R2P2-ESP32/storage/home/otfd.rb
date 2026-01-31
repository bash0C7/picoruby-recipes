# フィンガードラム装置（完全手動モード、IRQ方式）
DEBUG = false  # デバッグモード

require 'ws2812'
require 'gpio'
require 'irq'
require 'uart'

class FingerDrum
  MIDI_TX_PIN = 22
  MIDI_RX_PIN = 19

  # ボタン → ドラム音マッピング
  BUTTON_PINS = {
    39 => 49,  # GPIO39(内蔵) → CRASH (49)
    26 => 36,  # GPIO26(Grove) → KICK (36)
    32 => 38   # GPIO32(Grove) → SNARE (38)
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

class MatrixLED
  LED_PIN = 27
  LED_COUNT = 25

  # ボタン → RGB色マッピング（フラッシュ時の最大輝度版）
  FLASH_COLORS = {
    39 => {r: 255, g: 255, b: 0},    # CRASH → 鮮やかな黄色
    26 => {r: 255, g: 0, b: 0},      # KICK → 鮮やかな赤
    32 => {r: 0, g: 255, b: 255}     # SNARE → 鮮やかなシアン
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

# MIDI初期化
md_uart = UART.new(unit: :ESP32_UART1, baudrate: 31250, txd_pin: FingerDrum::MIDI_TX_PIN, rxd_pin: FingerDrum::MIDI_RX_PIN)
sleep_ms(10)
md_uart.clear_rx_buffer

# 内蔵LED初期化
led_strip = WS2812.new(RMTDriver.new(MatrixLED::LED_PIN))

# 装置初期化
drum = FingerDrum.new(md_uart)
led = MatrixLED.new(led_strip)

# 3つのボタンを個別に生成
button_39 = GPIO.new(39, GPIO::IN|GPIO::PULL_UP)
button_26 = GPIO.new(26, GPIO::IN|GPIO::PULL_UP)
button_32 = GPIO.new(32, GPIO::IN|GPIO::PULL_UP)

# GPIO39 IRQ登録（クラッシュシンバル）
irq_39 = button_39.irq(GPIO::EDGE_FALL, debounce: 10,
                       capture: {drum: drum, led: led, pin: 39}) do |btn, ev, cap|
  cap[:drum].play_note(cap[:pin])
  cap[:led].flash(cap[:pin])
end

# GPIO26 IRQ登録（バスドラム）
irq_26 = button_26.irq(GPIO::EDGE_FALL, debounce: 10,
                       capture: {drum: drum, led: led, pin: 26}) do |btn, ev, cap|
  cap[:drum].play_note(cap[:pin])
  cap[:led].flash(cap[:pin])
end

# GPIO32 IRQ登録（スネア）
irq_32 = button_32.irq(GPIO::EDGE_FALL, debounce: 10,
                       capture: {drum: drum, led: led, pin: 32}) do |btn, ev, cap|
  cap[:drum].play_note(cap[:pin])
  cap[:led].flash(cap[:pin])
end

# メインループ
loop do
  IRQ.process

  # LED常時アイドル表示（うっすらグレー）
  led.show_idle

  sleep_ms(1)
end

# 終了時に全IRQ解除
irq_39.unregister
irq_26.unregister
irq_32.unregister
