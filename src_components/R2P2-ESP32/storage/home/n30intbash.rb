# ATOM Matrix Internal 5x5 LED Control - Bash $ Icon
# Built-in WS2812 LEDs connected to GPIO 27
# Using picoruby-ws2812 gem

require 'ws2812'

puts "ATOM Matrix Internal LED - Bash $ Icon Starting..."

# LED設定
led_pin = 27
led_count = 25

# WS2812初期化
led = WS2812.new(RMTDriver.new(led_pin))

puts "LED initialized (GPIO 27, 25 LEDs)"

# 緑色設定（bash風カラー・安全な輝度）
green_r = 5
green_g = 25
green_b = 0
off_r = 0
off_g = 0
off_b = 0

puts "Displaying bash $ icon in green..."

# 5x5 LEDマトリックス用「$」マーク配列
# マトリックス配置：
# 0  1  2  3  4
# 5  6  7  8  9
# 10 11 12 13 14
# 15 16 17 18 19
# 20 21 22 23 24

# 「$」パターン（緑で光る部分を1、消灯を0）
dollar_pattern = [
  0, 1, 1, 1, 0,  # 上の横線
  1, 1, 0, 0, 0,  # 左上
  0, 1, 1, 1, 0,  # 中央横線
  0, 0, 0, 1, 1,  # 右下
  0, 1, 1, 1, 0   # 下の横線
]

# 色配列初期化
colors = Array.new(led_count) { [off_r, off_g, off_b] }

puts "Starting bash $ icon display..."

# 「$」アイコン点灯ループ
loop do
  # パターンに基づいて色設定
  led_count.times do |i|
    if dollar_pattern[i] == 1
      colors[i] = [green_r, green_g, green_b]
    else
      colors[i] = [off_r, off_g, off_b]
    end
  end
  
  # LED表示更新
  led.show_rgb(*colors)
  
  sleep_ms 1000  # 1秒間隔で更新
end