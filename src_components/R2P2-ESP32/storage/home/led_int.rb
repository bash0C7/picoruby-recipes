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

# 全LEDをオレンジ色で点灯
colors = Array.new(led_count) { [orange_r, orange_g, orange_b] }
led.show_rgb(*colors)

puts "Orange LEDs lit - brightness level 30"
puts "Program complete"

# 連続点灯維持
loop do
  sleep_ms 1000
end