# ATOM Matrix Internal 5x5 LED Control to GPIO 27 
# bashアイコン表示 - RGB直接指定による高精度表現 + 3軸加速度応答

require 'ws2812'
require 'mpu6886'
require 'gpio'

COLS = 5
ROWS = 5
LEDS = ROWS * COLS

HIGH = 1
LOW = 0

# GPIO 39 ボタン初期化
button = GPIO.new(39, GPIO::IN)

mpu = MPU6886.new(I2C.new(unit: :ESP32_I2C0, frequency: 100_000, sda_pin: 25, scl_pin: 21))
mpu.accel_range = MPU6886::ACCEL_RANGE_4G
led = WS2812.new(RMTDriver.new(27))

# bashアイコン（$記号）パターンを5x5マトリクスのRGB値で定義
# 各値は [R, G, B] で 0-255の範囲
base_bash_pattern = [
  # Row 0: 上の横線
  [[0, 0, 0], [100, 255, 50], [100, 255, 50], [100, 255, 50], [0, 0, 0]],
  # Row 1: 左上部
  [[100, 255, 50], [100, 255, 50], [0, 0, 0], [0, 0, 0], [0, 0, 0]],
  # Row 2: 中央横線
  [[0, 0, 0], [100, 255, 50], [100, 255, 50], [100, 255, 50], [0, 0, 0]],
  # Row 3: 右下部
  [[0, 0, 0], [0, 0, 0], [0, 0, 0], [100, 255, 50], [100, 255, 50]],
  # Row 4: 下の横線
  [[0, 0, 0], [100, 255, 50], [100, 255, 50], [100, 255, 50], [0, 0, 0]]
]

# 現在のLED状態を保存する配列
current_leds = Array.new(LEDS) { [0, 0, 0] }

puts "#{ROWS}x#{COLS} RGBアイコンパターン初期化完了"

# キャリブレーション処理メソッド
def calibrate_sensor(mpu)
  sx = sy = sz = 0
  puts "キャリブレーション開始..."
  
  5.times do |i|
    a = mpu.acceleration
    sx += (a[:x] * 100).to_i
    sy += (a[:y] * 100).to_i
    sz += (a[:z] * 100).to_i
    puts "測定#{i+1}: X=#{(a[:x] * 100).to_i}, Y=#{(a[:y] * 100).to_i}, Z=#{(a[:z] * 100).to_i}"
    sleep_ms 200
  end
  
  nx = sx / 5
  ny = sy / 5
  nz = sz / 5
  puts "基準値: X=#{nx}, Y=#{ny}, Z=#{nz}"
  return nx, ny, nz
end

# RGB値にアクセラレーション影響を適用
def apply_acceleration_color_shift(base_rgb, dx, dy, dz)
  r, g, b = base_rgb
  
  # 基本RGB値が0の場合（背景）はそのまま返す
  return [0, 0, 0] if r == 0 && g == 0 && b == 0
  
  # 加速度の影響を計算（-200〜+200の範囲を-1.0〜+1.0にマッピング）
  x_influence = (dx.to_f / 200.0).clamp(-1.0, 1.0)
  y_influence = (dy.to_f / 200.0).clamp(-1.0, 1.0)
  z_influence = (dz.to_f / 200.0).clamp(-1.0, 1.0)
  
  # 基本色に加速度による色シフトを適用
  # X軸 → 青成分シフト, Y軸 → 緑成分シフト, Z軸 → 赤成分シフト
  new_r = (r + z_influence * 100).clamp(0, 255).to_i
  new_g = (g + y_influence * 100).clamp(0, 255).to_i  
  new_b = (b + x_influence * 100).clamp(0, 255).to_i
  
  # WS2812用に0-31の範囲に変換
  [(new_r / 8.2).to_i, (new_g / 8.2).to_i, (new_b / 8.2).to_i]
end

# 初回キャリブレーション実行
nx, ny, nz = calibrate_sensor(mpu)

last_button = HIGH
button_wait = 0

puts "bashアイコンRGB LEDマトリクス開始"
puts "X軸→青シフト, Y軸→緑シフト, Z軸→赤シフト"

loop do
  current_button = button.read
  
  # ボタン押下検出
  if last_button == HIGH && current_button == LOW && button_wait == 0
    puts "再キャリブレーション実行中..."
    nx, ny, nz = calibrate_sensor(mpu)
    button_wait = 10
  end
  
  last_button = current_button
  button_wait -= 1 if button_wait > 0
  
  # 現在の加速度を取得
  a = mpu.acceleration
  
  # 基準値からの差分を計算
  dx = (a[:x] * 100).to_i - nx
  dy = (a[:y] * 100).to_i - ny
  dz = (a[:z] * 100).to_i - nz
  
  # 5x5マトリクスの各LEDに色を適用
  ROWS.times do |row|
    COLS.times do |col|
      led_index = row * COLS + col
      base_rgb = base_bash_pattern[row][col]
      
      # 加速度による色シフトを適用
      shifted_rgb = apply_acceleration_color_shift(base_rgb, dx, dy, dz)
      current_leds[led_index] = shifted_rgb
    end
  end
  
  # LED表示を更新
  led.show_rgb(*current_leds)
  
  # 加速度の大きさを計算してデバッグ出力
  magnitude = Math.sqrt(dx*dx + dy*dy + dz*dz).to_i
  print "動き:#{magnitude} X:#{dx} Y:#{dy} Z:#{dz} "
  
  sleep_ms 50
end
