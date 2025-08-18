# ATOM Matrix外付けLED光源ペンライト + MIDI効果音
require 'unitasr'
require 'ws2812'
require 'uart'

# LED設定
led_pin = 22
led_count = 90
led = WS2812.new(RMTDriver.new(led_pin))

# 色変数
orange_r = 200
orange_g = 100
orange_b = 0
colors = Array.new(led_count) { [orange_r, orange_g, orange_b] }

# UART設定（ASR用）
UART_TX = 26
UART_RX = 32
asr = UnitASR.new(UART.new(unit: :ESP32_UART1, baudrate: 115200, txd_pin: UART_TX, rxd_pin: UART_RX))

# MIDI UART設定（別のピン使用）
MIDI_TX = 23  # J4のG23ピン
MIDI_RX = 33  # J4のG33ピン  
midi_uart = UART.new(unit: :ESP32_UART0, baudrate: 31250, txd_pin: MIDI_TX, rxd_pin: MIDI_RX)

# MIDI効果音再生関数
def play_effect_sound(uart, program, note, velocity, duration_ms)
  # 楽器設定
  status = (0xC0 + 0).chr  # Program Change Ch0
  prog_byte = program.chr
  uart.write(status + prog_byte)
  sleep_ms(10)
  
  # Note On
  status = (0x90 + 0).chr  # Note On Ch0
  note_byte = note.chr
  vel_byte = velocity.chr
  uart.write(status + note_byte + vel_byte)
  sleep_ms(duration_ms)
  
  # Note Off
  status = (0x80 + 0).chr  # Note Off Ch0
  vel_byte = 0.chr
  uart.write(status + note_byte + vel_byte)
end

# 初期化
sleep_ms(1000)

# コマンドハンドラー登録
asr.on(0x17) do  # "pause" - Breath Noise
  orange_r = 10
  orange_g = 5
  orange_b = 0
  play_effect_sound(midi_uart, 121, 60, 80, 800)  # Breath Noise
end

asr.on(0x30) do  # "ok" - Applause
  orange_r = 50
  orange_g = 20
  orange_b = 0
  play_effect_sound(midi_uart, 126, 60, 100, 1200)  # Applause
end

asr.on(0x10) do  # "open" - 風の音
  orange_r = 220
  orange_g = 140
  orange_b = 0
  play_effect_sound(midi_uart, 99, 40, 110, 1500)  # Atmosphere（低めの音程で風感）
end

loop do
  asr.update
  
  led_count.times do |i|
    colors[i] = [orange_r, orange_g, orange_b]
  end
  
  led.show_rgb(*colors)
  
  sleep_ms 50
end
