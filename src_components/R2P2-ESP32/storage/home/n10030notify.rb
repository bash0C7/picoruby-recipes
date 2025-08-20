# Claude Code Notify
# WS2812 LED strip connected to J5 port (G22)
# Using picoruby-ws2812 gem
require 'ws2812'
require 'uart'

# LED設定
led_pin = 22
led_count = 30

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
      # 簡単な赤点灯
      (0...led_count).each { |i| 
        colors[i][0] = 100
        colors[i][1] = 20
        colors[i][2] = 0
      }
      led.show_rgb(*colors)
      
    elsif input == "g"
      uart.puts "G" 
      # 簡単な緑点灯
      (0...led_count).each { |i| 
        colors[i][0] = 20
        colors[i][1] = 100
        colors[i][2] = 0
      }
      led.show_rgb(*colors)
      
    elsif input == "b"
      uart.puts "B"
      # 簡単な青点灯
      (0...led_count).each { |i| 
        colors[i][0] = 0
        colors[i][1] = 20
        colors[i][2] = 100
      }
      led.show_rgb(*colors)
    end
    sleep_ms(3000)
  end
  # 消灯
  (0...led_count).each { |i| 
    colors[i][0] = 0
    colors[i][1] = 0
    colors[i][2] = 0
  }
  led.show_rgb(*colors)
  
  sleep_ms(100)
end
