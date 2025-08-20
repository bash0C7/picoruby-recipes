# ATOM Matrix Internal 5x5 LED Control 
# M5Stack ATOM Matrixを使用した、振動応答型紅玉LEDデモンストレーション。デバイスを上下左右に振ることで、5x5 LEDマトリックス上の紅玉が液体のように自然に動く物理シミュレーションを実現。
# Built-in WS2812 LEDs connected to GPIO 27
# Using picoruby-ws2812 gem

require 'ws2812'
require 'mpu6886'

puts "Ruby Gemstone Demo Starting..."

# ハードウェア初期化
puts "Initializing hardware..."

# I2C初期化（MPU6886用）
i2c = I2C.new(unit: :ESP32_I2C0, frequency: 100_000, sda_pin: 25, scl_pin: 21)

# センサー初期化
mpu = MPU6886.new(i2c)
mpu.accel_range = MPU6886::ACCEL_RANGE_4G

# LED初期化（内蔵5x5マトリックス）
led = WS2812.new(RMTDriver.new(27))

puts "Hardware initialized (MPU6886 + 25 LEDs)"

# 紅玉パターン定義（ニュートラル位置）
# □□□□□
# □□■□□  ← LED index: 7
# □■■■□  ← LED index: 11, 12, 13
# □□■□□  ← LED index: 17
# □□□□□
ruby_pattern = [7, 11, 12, 13, 17]

puts "Ruby pattern: Diamond shape (5 LEDs)"

# 色定義（RGB値 / 8 で輝度調整）
colors = {
  deep_red: [31, 0, 0],      # 0xFF0000 >> 3 - 静止状態
  pink: [31, 8, 16],         # 0xFF4080 >> 3 - 穏やか動作  
  purple: [16, 8, 31]        # 0x8040FF >> 3 - アクティブ動作
}

# LED配列事前確保（メモリ最適化）
led_array = []
25.times { led_array << [0, 0, 0] }

puts "Colors defined: deep_red, pink, purple"

# キャリブレーション（5回平均でニュートラル位置確定）
puts "Calibrating... (5 samples)"
sum_x = sum_y = 0

5.times do |i|
  accel = mpu.acceleration
  sum_x += (accel[:x] * 100).to_i
  sum_y += (accel[:y] * 100).to_i
  puts "Sample #{i+1}: X=#{(accel[:x] * 100).to_i}, Y=#{(accel[:y] * 100).to_i}"
  sleep_ms 200
end

neutral_x = sum_x / 5
neutral_y = sum_y / 5

puts "Neutral position: X=#{neutral_x}, Y=#{neutral_y}"
puts "Starting gemstone simulation..."
puts "---"

# 制御変数初期化
prev_shift_x = 0
prev_shift_y = 0
deadzone = 8
gentle_threshold = 25

# メインループ
loop do
  # 加速度取得
  accel = mpu.acceleration
  
  # ニュートラルからの差分計算
  raw_x = (accel[:x] * 100).to_i - neutral_x
  raw_y = (accel[:y] * 100).to_i - neutral_y
  
  # 動き強度計算（平方根回避でメモリ節約）
  motion_intensity = raw_x * raw_x + raw_y * raw_y
  
  # デッドゾーン制御（ちらつき防止）
  if motion_intensity < (deadzone * deadzone)
    # デッドゾーン内：前回位置維持
    shift_x = prev_shift_x
    shift_y = prev_shift_y
  else
    # デッドゾーン外：動的制御
    
    # 動的スケーリング
    if motion_intensity < (gentle_threshold * gentle_threshold)
      scale = 80  # 穏やか動作：高減衰
    else
      scale = 15  # ダイナミック動作：低減衰
    end
    
    # 新しい位置計算
    new_shift_x = raw_x / scale
    new_shift_y = raw_y / scale
    
    # 移動範囲制限（-4 ～ +4）
    shift_x = new_shift_x > 4 ? 4 : new_shift_x < -4 ? -4 : new_shift_x
    shift_y = new_shift_y > 4 ? 4 : new_shift_y < -4 ? -4 : new_shift_y
    
    # 前回位置更新
    prev_shift_x = shift_x
    prev_shift_y = shift_y
  end
  
  # 動き強度による色選択
  current_color = colors[:deep_red]  # デフォルト：深紅
  
  if motion_intensity > 600
    current_color = colors[:pink]    # 穏やか：ピンク
  end
  
  if motion_intensity > 2400
    current_color = colors[:purple]  # アクティブ：紫
  end
  
  # LED配列クリア
  25.times do |i|
    led_array[i] = [0, 0, 0]
  end
  
  # 紅玉描画
  ruby_pattern.each do |pattern_index|
    # パターンからLEDマトリックス座標計算
    pattern_x = pattern_index % 5
    pattern_y = pattern_index / 5
    
    # 移動後の座標計算
    led_x = pattern_x + shift_x
    led_y = pattern_y + shift_y
    
    # 境界チェック（画面外流出対応）
    if led_x >= 0 && led_x < 5 && led_y >= 0 && led_y < 5
      led_index = led_y * 5 + led_x
      led_array[led_index] = current_color
    end
  end
  
  # LED表示更新
  led.show_rgb(*led_array)
  
  # デバッグ情報（メモリ節約版）
  if motion_intensity < (deadzone * deadzone)
    print "S"  # Static
  elsif motion_intensity < (gentle_threshold * gentle_threshold)
    print "G"  # Gentle
  else
    print "D"  # Dynamic
  end
  
  # 制御周期（50ms = 20Hz）
  sleep_ms 50
end
