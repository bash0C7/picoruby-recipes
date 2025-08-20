# ATOM Matrix Internal 5x5 LED Control to GPIO 27 
# Ruby Gemstone Demo - 振動応答型LEDパターンシミュレーション (ボタンキャリブレーション版)

require 'ws2812'
require 'mpu6886'
require 'gpio'

COLS = 5
pattern_rows = [
  0b00000,
  0b00100,
  0b01110,
  0b00100,
  0b00000
]

ROWS = pattern_rows.length
LEDS = ROWS * COLS

HIGH = 1
LOW = 0

# GPIO 39 ボタン初期化
button = GPIO.new(39, GPIO::IN)

mpu = MPU6886.new(I2C.new(unit: :ESP32_I2C0, frequency: 100_000, sda_pin: 25, scl_pin: 21))
mpu.accel_range = MPU6886::ACCEL_RANGE_4G
led = WS2812.new(RMTDriver.new(27))

pattern_count = 0
pattern_rows.each do |row|
  temp = row
  while temp > 0
    pattern_count += 1 if temp & 1 == 1
    temp >>= 1
  end
end

pattern = Array.new(pattern_count)
idx = 0
ROWS.times do |r|
  COLS.times do |c|
    if (pattern_rows[r] >> (COLS - 1 - c)) & 1 == 1
      pattern[idx] = r * COLS + c
      idx += 1
    end
  end
end

colors = [[31, 0, 0], [31, 8, 16], [16, 8, 31]]
leds = Array.new(LEDS) { [0, 0, 0] }

puts "#{ROWS}x#{COLS} (#{LEDS} LEDs) Pattern: #{pattern}"

# キャリブレーション処理メソッド
def calibrate_sensor(mpu)
  sx = sy = 0
  5.times do |i|
    a = mpu.acceleration
    sx += (a[:x] * 100).to_i
    sy += (a[:y] * 100).to_i
    puts "#{i+1}: #{(a[:x] * 100).to_i}, #{(a[:y] * 100).to_i}"
    sleep_ms 200
  end
  
  nx = sx / 5
  ny = sy / 5
  return nx, ny
end

# 初回キャリブレーション実行
nx, ny = calibrate_sensor(mpu)
puts "Initial Neutral: #{nx}, #{ny}"

px = py = 0
last_button = HIGH
button_wait = 0

loop do
  current_button = button.read
  
  # ボタン押下検出（HIGHからLOWへの変化）
  if last_button == HIGH && current_button == LOW && button_wait == 0
    puts "Button: Re-calibrating..."
    nx, ny = calibrate_sensor(mpu)
    puts "Updated Neutral: #{nx}, #{ny}"
    button_wait = 4  # 4回ループ待機（200msデバウンス）
  end
  
  last_button = current_button
  button_wait -= 1 if button_wait > 0
  
  # メインLEDパターン処理
  a = mpu.acceleration
  rx = (a[:x] * 100).to_i - nx
  ry = (a[:y] * 100).to_i - ny
  mi = rx * rx + ry * ry
  
  if mi < 64
    x = px
    y = py
  else
    s = mi < 625 ? 80 : 15
    x = rx / s
    y = ry / s
    x = x > 4 ? 4 : x < -4 ? -4 : x
    y = y > 4 ? 4 : y < -4 ? -4 : y
    px = x
    py = y
  end
  
  c = mi > 2400 ? colors[2] : mi > 600 ? colors[1] : colors[0]
  
  LEDS.times { |i| leds[i] = [0, 0, 0] }
  
  pattern.each do |p|
    lx = p % COLS + x
    ly = p / COLS + y
    leds[ly * COLS + lx] = c if lx >= 0 && lx < COLS && ly >= 0 && ly < ROWS
  end
  
  led.show_rgb(*leds)
  print mi < 64 ? "S" : mi < 625 ? "G" : "D"
  sleep_ms 50
end
