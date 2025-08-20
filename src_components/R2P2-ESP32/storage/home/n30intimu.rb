# ATOM Matrix Internal 5x5 LED Control 
# Built-in WS2812 LEDs connected to GPIO 27
# Using picoruby-ws2812 gem
# Ruby Gemstone Demo - 振動応答型LEDパターンシミュレーション
# M5Stack ATOM Matrix用 - 振る動作でLEDパターンが液体のように動く物理シミュレーション

require 'ws2812'
require 'mpu6886'

puts "LED Pattern Demo Starting..."

pattern_rows = [
  0b00000,
  0b00100,
  0b01110,
  0b00100,
  0b00000
]

MATRIX_ROWS = pattern_rows.length
cols = 0
temp = pattern_rows[0]
while temp > 0
  cols += 1
  temp >>= 1
end
MATRIX_COLS = cols
TOTAL_LEDS = MATRIX_ROWS * MATRIX_COLS

puts "Matrix size: #{MATRIX_ROWS}x#{MATRIX_COLS} (#{TOTAL_LEDS} LEDs)"

puts "Initializing hardware..."

mpu = MPU6886.new(I2C.new(unit: :ESP32_I2C0, frequency: 100_000, sda_pin: 25, scl_pin: 21))
mpu.accel_range = MPU6886::ACCEL_RANGE_4G
led = WS2812.new(RMTDriver.new(27))

puts "Hardware initialized (MPU6886 + #{TOTAL_LEDS} LEDs)"

led_pattern = []
MATRIX_ROWS.times do |row|
  MATRIX_COLS.times do |col|
    if (pattern_rows[row] >> (MATRIX_COLS - 1 - col)) & 1 == 1
      led_pattern << row * MATRIX_COLS + col
    end
  end
end

puts "LED pattern generated: #{led_pattern.length} LEDs active"
puts "Pattern: #{led_pattern}"

COLORS = {
  deep_red: [31, 0, 0],
  pink: [31, 8, 16],
  purple: [16, 8, 31]
}

led_array = []
TOTAL_LEDS.times { led_array << [0, 0, 0] }

puts "Colors defined: deep_red, pink, purple"

puts "Calibrating... (5 samples)"
sum_x = sum_y = 0

5.times do |i|
  accel = mpu.acceleration
  sum_x += (accel[:x] * 100).to_i
  sum_y += (accel[:y] * 100).to_i
  puts "Sample #{i+1}: X=#{(accel[:x] * 100).to_i}, Y=#{(accel[:y] * 100).to_i}"
  sleep_ms 200
end

NEUTRAL_X = sum_x / 5
NEUTRAL_Y = sum_y / 5

puts "Neutral position: X=#{NEUTRAL_X}, Y=#{NEUTRAL_Y}"
puts "Starting pattern simulation..."
puts "---"

prev_shift_x = 0
prev_shift_y = 0
DEADZONE = 8
GENTLE_THRESHOLD = 25

loop do
  accel = mpu.acceleration
  
  raw_x = (accel[:x] * 100).to_i - NEUTRAL_X
  raw_y = (accel[:y] * 100).to_i - NEUTRAL_Y
  motion_intensity = raw_x * raw_x + raw_y * raw_y
  
  if motion_intensity < (DEADZONE * DEADZONE)
    shift_x = prev_shift_x
    shift_y = prev_shift_y
  else
    if motion_intensity < (GENTLE_THRESHOLD * GENTLE_THRESHOLD)
      scale = 80
    else
      scale = 15
    end
    
    new_shift_x = raw_x / scale
    new_shift_y = raw_y / scale
    
    shift_x = new_shift_x > 4 ? 4 : new_shift_x < -4 ? -4 : new_shift_x
    shift_y = new_shift_y > 4 ? 4 : new_shift_y < -4 ? -4 : new_shift_y
    
    prev_shift_x = shift_x
    prev_shift_y = shift_y
  end
  
  current_color = COLORS[:deep_red]
  
  if motion_intensity > 600
    current_color = COLORS[:pink]
  end
  
  if motion_intensity > 2400
    current_color = COLORS[:purple]
  end
  
  TOTAL_LEDS.times do |i|
    led_array[i] = [0, 0, 0]
  end
  
  led_pattern.each do |pattern_index|
    pattern_x = pattern_index % MATRIX_COLS
    pattern_y = pattern_index / MATRIX_COLS
    
    led_x = pattern_x + shift_x
    led_y = pattern_y + shift_y
    
    if led_x >= 0 && led_x < MATRIX_COLS && led_y >= 0 && led_y < MATRIX_ROWS
      led_index = led_y * MATRIX_COLS + led_x
      led_array[led_index] = current_color
    end
  end
  
  led.show_rgb(*led_array)
  
  if motion_intensity < (DEADZONE * DEADZONE)
    print "S"
  elsif motion_intensity < (GENTLE_THRESHOLD * GENTLE_THRESHOLD)
    print "G"
  else
    print "D"
  end
  
  sleep_ms 50
end
