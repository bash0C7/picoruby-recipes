
# ATOM Matrix外付けLED光源ペンライト
require 'unitasr'
require 'ws2812'

led_pin = 22
led_count = 90

led = WS2812.new(RMTDriver.new(led_pin))

orange_r = 200
orange_g = 100
orange_b = 0
colors = Array.new(led_count) { [orange_r, orange_g, orange_b] }

require 'uart'

UART_TX = 26
UART_RX = 32

asr = UnitASR.new(UART.new(unit: :ESP32_UART1, baudrate: 115200, txd_pin: UART_TX, rxd_pin: UART_RX))

# コマンドハンドラー登録
asr.add_handler(0x17) do  # "pause"
  orange_r = 20
  orange_g = 10
  orange_b = 0
end

asr.add_handler(0x30) do  # "ok"
  orange_r = 100
  orange_g = 50
  orange_b = 0
end

asr.add_handler(0x10) do  # "open"
  orange_r = 220
  orange_g = 140
  orange_b = 0
end

loop do
  #Hi M Five, pause, ok, open
  asr.update
  
  led_count.times do |i|
    colors[i] = [orange_r, orange_g, orange_b]
  end
  
  led.show_rgb(*colors)
  
  sleep_ms 50
end
