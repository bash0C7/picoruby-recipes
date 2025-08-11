# ATOM Matrix Internal 5x5 LED Control - Simple Orange Light
# Built-in WS2812 LEDs connected to GPIO 27
# Using picoruby-ws2812 gem

require 'ws2812'

puts "ATOM Matrix Internal LED Starting..."

# LED設定
led_pin = 27
led_count = 25

# WS2812初期化
led = WS2812.new(RMTDriver.new(led_pin))

puts "LED initialized (GPIO 27, 25 LEDs)"

# オレンジ色設定（安全な輝度30）
orange_r = 30
orange_g = 15
orange_b = 0

puts "Setting all LEDs to orange color..."

# 色配列初期化
colors = Array.new(led_count) { [orange_r, orange_g, orange_b] }

puts "Starting continuous LED display..."

# 連続点灯ループ
loop do
  # 毎回色を設定してLED更新
  led_count.times do |i|
    colors[i] = [orange_r, orange_g, orange_b]
  end
  
  # LED表示更新
  led.show_rgb(*colors)
  
  sleep_ms 100  # 100ms間隔で更新
end