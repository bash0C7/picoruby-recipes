# Claude Code Notify
# WS2812 LED strip connected to J5 port (G22)
# Using picoruby-ws2812 gem
require 'ws2812'
require 'uart'

uart = UART.new(unit: :ESP32_UART0, baudrate: 115200)

# LED設定
led_pin = 22
led_count = 60

# WS2812初期化
led = WS2812.new(RMTDriver.new(led_pin))

puts "LED initialized (GPIO #{led_pin}, #{led_count} LEDs)"

# オレンジ色設定
orange_r = 10
orange_g = 5
orange_b = 0

# 色配列初期化
colors = Array.new(led_count) { [orange_r, orange_g, orange_b] }

# 連続点灯ループ
loop do
  input = uart.read
  if input && input.length > 0
    puts input
    
    if input == "r"
      uart.puts "R"
      # 実例パターン：配列全体を再代入
      led_count.times do |i|
        colors[i] = [100, 20, 0]  # 赤色
      end
      led.show_rgb(*colors)
      
    elsif input == "g"
      uart.puts "G" 
      # 実例パターン：配列全体を再代入
      led_count.times do |i|
        colors[i] = [20, 100, 0]  # 緑色
      end
      led.show_rgb(*colors)
      
    elsif input == "b"
      uart.puts "B"
      # 実例パターン：配列全体を再代入
      led_count.times do |i|
        colors[i] = [0, 20, 100]  # 青色
      end
      led.show_rgb(*colors)
    end
    sleep_ms(3000)
  end
  
  # 消灯 - 実例パターン：配列全体を再代入
  led_count.times do |i|
    colors[i] = [0, 0, 0]  # 完全消灯
  end
  led.show_rgb(*colors)
  
  sleep_ms(100)
end
