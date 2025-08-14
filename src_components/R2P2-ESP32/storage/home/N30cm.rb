
# N30cm.rb - ATOM Matrix外付けLED光源ペンライト
# 
# ATOM Matrixの外付け15 LEDバー(15個)を光源として使用
# 30cmのアクリル透明筒にトレーシングペーパーを巻いたペンライト演出
# 光を拡散させて柔らかい照明効果を実現
# 外付けWS2812 LEDs GPIO 32(Grove)経由接続
# 
# 熱保護・輝度保護のため中央3個のみ点灯
# 点灯LED: 7, 8, 9番目（インデックス6, 7, 8）
# 15LED配置: [0][1][2][3][4][5][6][7][8][9][10][11][12][13][14]
#                              ↑ ↑ ↑ ← 中央3個

require 'ws2812'

puts "ATOM Matrix External LED Starting..."

# LED設定
led_pin = 32
led_count = 15

# WS2812初期化
led = WS2812.new(RMTDriver.new(led_pin))

puts "LED initialized (GPIO #{led_pin}, #{led_count} LEDs)"

# オレンジ色設定（最大輝度100に設定）
orange_r = 100
orange_g = 50
orange_b = 0

# はじっこのLED位置（0, 1番目）
center_leds = [0, 1]

puts "Setting center 3 LEDs to orange (heat protection mode)..."

# 全LED消灯で初期化
colors = Array.new(led_count) { [0, 0, 0] }

# 中央3個のみオレンジ色設定
center_leds.each do |led_index|
  colors[led_index] = [orange_r, orange_g, orange_b]
end

puts "Starting continuous LED display (center 3 LEDs only)..."

# 初回全消灯を確実に実行
puts "Clearing all LEDs first..."
led.show_rgb(*Array.new(led_count) { [0, 0, 0] })
sleep_ms 200

puts "Applying center pattern..."

# 連続点灯ループ
loop do
  # 毎回全LEDを明示的にリセット
  led_count.times do |i|
    if center_leds.include?(i)
      colors[i] = [orange_r, orange_g, orange_b]
    else
      colors[i] = [0, 0, 0]  # 確実に消灯
    end
  end
  
  # LED表示更新
  led.show_rgb(*colors)
  
  sleep_ms 100  # 100ms間隔で更新
end
