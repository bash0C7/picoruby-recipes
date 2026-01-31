# フィンガードラム装置（完全手動モード）
DEBUG = false  # デバッグモード

require 'ws2812'
require 'gpio'
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
    @buttons = {}
    @button_states = {}

    BUTTON_PINS.each do |pin, note|
      @buttons[pin] = GPIO.new(pin, GPIO::IN|GPIO::PULL_UP)
      @button_states[pin] = false
    end
  end

  def update
    # ポーリング: ボタン状態をチェック、エッジ検出
    BUTTON_PINS.each do |pin, note|
      current = @buttons[pin].read == 0  # LOW = 押下
      prev = @button_states[pin]

      if !prev && current  # 押下エッジ
        play_note(note)
        puts "Button #{pin} pressed → Note #{note}" if DEBUG
      end

      @button_states[pin] = current
    end
  end

  def play_note(note)
    @uart.write((0x99).chr + note.chr + (0x7F).chr)
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

# メインループ
loop do
  # ボタンポーリング
  drum.update

  # LED更新（ボタン状態に基づく）
  led.update(drum.button_states)
  led.show

  sleep_ms(1)
end
