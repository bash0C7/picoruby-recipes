# ランダムカラー表示デモ - 時刻ベース疑似乱数色変化
# 内蔵5x5 LED(GPIO 27) + 時刻種子カラー生成

require 'ws2812'

puts "ATOM Matrix Internal LED Starting..."

# LED設定
led_pin = 27
led_count = 25

# WS2812初期化
led = WS2812.new(RMTDriver.new(led_pin))

puts "LED initialized (GPIO 27, 25 LEDs)"

# デフォルトオレンジ色設定（安全な輝度30）
orange_r = 30
orange_g = 15
orange_b = 0

puts "Setting all LEDs to orange color..."

# 色配列初期化
colors = Array.new(led_count) { [orange_r, orange_g, orange_b] }

puts "Starting continuous LED display..."

# 連続点灯ループ
loop do
  time_seed = Time.now.to_i
  # 各成分で異なる計算をして変化をつける
  r_random = (time_seed % 50)
  g_random = ((time_seed * 3) % 15) 
  b_random = ((time_seed * 7) % 180)
  
  # 毎回色に乱数を加えてLED更新
  led_count.times do |i|
    time_seed = Time.now.to_i
    colors[i] = [orange_r + r_random, orange_g  + orange_g + g_random, orange_b + b_random]
  end
  
  # LED表示更新
  led.show_rgb(*colors)
  
  sleep_ms 100  # 100ms間隔で更新
end
