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
    @button_states = {39 => false, 26 => false, 32 => false}
  end

  def play_note(pin)
    note = BUTTON_PINS[pin]
    @uart.write((0x99).chr + note.chr + (0x7F).chr)
    puts "Button #{pin} pressed → Note #{note}" if DEBUG
  end

  def press(pin)
    @button_states[pin] = true
  end

  def release(pin)
    @button_states[pin] = false
  end

  def button_states
    @button_states
  end
end

class MatrixLED
  LED_PIN = 27
  LED_COUNT = 25

  # ボタン → RGB色マッピング（1/3輝度で発熱防止）
  BUTTON_COLORS = {
    39 => {r: 85, g: 85, b: 0},    # CRASH → 黄色
    26 => {r: 85, g: 0, b: 0},     # KICK → 赤
    32 => {r: 0, g: 85, b: 85}     # SNARE → シアン
  }

  def initialize(led_strip)
    @led_strip = led_strip
    @led_colors = Array.new(LED_COUNT, [0, 0, 0])
  end

  def update(button_states)
    # RGB加算合成
    r_sum = 0
    g_sum = 0
    b_sum = 0

    button_states.each do |pin, pressed|
      if pressed
        color = BUTTON_COLORS[pin]
        r_sum += color[:r]
        g_sum += color[:g]
        b_sum += color[:b]
      end
    end

    # 255でクランプ
    final_r = r_sum.clamp(0, 255)
    final_g = g_sum.clamp(0, 255)
    final_b = b_sum.clamp(0, 255)

    # 全LEDを同一色に設定
    LED_COUNT.times do |i|
      @led_colors[i] = [final_r, final_g, final_b]
    end

    if DEBUG
      puts "LED: R#{final_r} G#{final_g} B#{final_b}"
    end
  end

  def show
    @led_strip.show_rgb(*@led_colors)
  end
end

# MIDI初期化
md_uart = UART.new(unit: :ESP32_UART1, baudrate: 31250, txd_pin: FingerDrum::MIDI_TX_PIN, rxd_pin: FingerDrum::MIDI_RX_PIN)
sleep_ms(10)
md_uart.clear_rx_buffer

# MIDI Bank Select + Program Change
md_uart.write((0xB9).chr + (32).chr + (16).chr)
sleep_ms(10)
md_uart.write((0xC9).chr + (0).chr)
sleep_ms(10)

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
irq_39 = button_39.irq(GPIO::EDGE_FALL | GPIO::EDGE_RISE, debounce: 100,
                       capture: {drum: drum, pin: 39}) do |btn, ev, cap|
  case ev
  when GPIO::EDGE_FALL  # 押下
    cap[:drum].play_note(cap[:pin])
    cap[:drum].press(cap[:pin])
  when GPIO::EDGE_RISE  # リリース
    cap[:drum].release(cap[:pin])
  end
end

# GPIO26 IRQ登録（バスドラム）
irq_26 = button_26.irq(GPIO::EDGE_FALL | GPIO::EDGE_RISE, debounce: 100,
                       capture: {drum: drum, pin: 26}) do |btn, ev, cap|
  case ev
  when GPIO::EDGE_FALL
    cap[:drum].play_note(cap[:pin])
    cap[:drum].press(cap[:pin])
  when GPIO::EDGE_RISE
    cap[:drum].release(cap[:pin])
  end
end

# GPIO32 IRQ登録（スネア）
irq_32 = button_32.irq(GPIO::EDGE_FALL | GPIO::EDGE_RISE, debounce: 100,
                       capture: {drum: drum, pin: 32}) do |btn, ev, cap|
  case ev
  when GPIO::EDGE_FALL
    cap[:drum].play_note(cap[:pin])
    cap[:drum].press(cap[:pin])
  when GPIO::EDGE_RISE
    cap[:drum].release(cap[:pin])
  end
end

# メインループ
loop do
  IRQ.process

  # LED更新（ボタン状態に基づく）
  led.update(drum.button_states)
  led.show

  sleep_ms(1)
end

# 終了時に全IRQ解除
irq_39.unregister
irq_26.unregister
irq_32.unregister
