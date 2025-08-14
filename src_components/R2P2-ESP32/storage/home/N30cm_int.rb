# N30cm_int.rb - ATOM Matrix内蔵LED光源ペンライト
# 
# ATOM Matrixの内蔵5x5 LEDマトリックス(25個)を光源として使用
# 30cmのアクリル透明筒にトレーシングペーパーを巻いたペンライト演出
# 光を拡散させて柔らかい照明効果を実現
# GPIO27のWS2812C LEDを制御
# 
# 熱保護・輝度保護のため中央十字パターンのみ点灯
# 点灯LED: C2(7), B3(11), C3(12), D3(13), C4(17)
# 5x5マトリックス配置（0-24インデックス）:
#   0  1  2  3  4  (行1: A1-E1)
#   5  6  7  8  9  (行2: A2-E2) ← C2=7
#  10 11 12 13 14  (行3: A3-E3) ← B3=11, C3=12, D3=13  
#  15 16 17 18 19  (行4: A4-E4) ← C4=17
#  20 21 22 23 24  (行5: A5-E5)

require 'ws2812'

puts "ATOM Matrix Internal LED Starting..."

# LED設定
led_pin = 27
led_count = 25

# WS2812初期化
led = WS2812.new(RMTDriver.new(led_pin))

puts "LED initialized (GPIO #{led_pin}, #{led_count} LEDs)"

# オレンジ色設定
orange_r = 200
orange_g = 100 
orange_b = 0

# 中央十字パターン点灯LED位置
cross_pattern = [7, 11, 12, 13, 17]  # C2, B3, C3, D3, C4

puts "Setting cross pattern LEDs to orange (heat protection mode)..."

# 全LED消灯で初期化
colors = Array.new(led_count) { [0, 0, 0] }

# 中央十字パターンのみオレンジ色設定
cross_pattern.each do |led_index|
  colors[led_index] = [orange_r, orange_g, orange_b]
end

puts "Starting continuous LED display (cross pattern only)..."

# 初回全消灯を確実に実行
puts "Clearing all LEDs first..."
led.show_rgb(*Array.new(led_count) { [0, 0, 0] })
sleep_ms 200

puts "Applying cross pattern..."

# 連続点灯ループ
loop do
  # 毎回全LEDを明示的にリセット
  led_count.times do |i|
    if cross_pattern.include?(i)
      colors[i] = [orange_r, orange_g, orange_b]
    else
      colors[i] = [0, 0, 0]  # 確実に消灯
    end
  end
  
  # LED表示更新
  led.show_rgb(*colors)
  
  sleep_ms 100  # 100ms間隔で更新
end
