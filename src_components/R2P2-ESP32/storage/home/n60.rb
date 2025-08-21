
# ATOM Matrix外付けLED光源ペンライト
# 
# ATOM Matrixの外付け60 LEDストリップ(MAX90個)を光源として使用
# 100cmのアクリル透明筒にトレーシングペーパーを巻いたペンライト演出
# 光を拡散させて柔らかい照明効果を実現
# WS2812 LED strip connected to J5 port (G22)
# Using picoruby-ws2812 gem

require 'ws2812'

puts "ATOM Matrix Internal LED Starting..."

# LED設定
led_pin = 22
led_count = 60

# WS2812初期化
led = WS2812.new(RMTDriver.new(led_pin))

puts "LED initialized (GPIO #{led_pin}, #{led_count} LEDs)"

# オレンジ色設定
orange_r = 200
orange_g = 100
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
