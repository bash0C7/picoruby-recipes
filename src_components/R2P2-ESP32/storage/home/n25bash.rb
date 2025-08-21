require 'ws2812'
require 'mpu6886'
require 'gpio'

puts "1: start"

BASE_BASH = [
  [0xdbb48b, 0xe3bc8e, 0xca2c12, 0xb95c47, 0xe0b489],
  [0xe04a0d, 0xfd7910, 0xf3000b, 0xf90007, 0xfb7a10],
  [0xc37260, 0xd23006, 0xc60004, 0xf2500d, 0xef651b],
  [0xfce7c0, 0xda3e05, 0xfac476, 0xdc190b, 0xcc8a5b],
  [0xd40004, 0xf10009, 0xc52006, 0xef0007, 0x8c0003]
]

ROWS = BASE_BASH.size
COLS = BASE_BASH[0].size  
LEDS = ROWS * COLS

CHARS = {
  'b' => 0b1111010001111010001111000000000000000,
  'a' => 0b0111010001111111000010001000100000000,
  's' => 0b0111110000011100000111111000000000000,
  'h' => 0b1000110001111111000110001000100000000
}

puts "2: data"

button = GPIO.new(39, GPIO::IN)
mpu = MPU6886.new(I2C.new(unit: :ESP32_I2C0, frequency: 100_000, sda_pin: 25, scl_pin: 21))
mpu.accel_range = MPU6886::ACCEL_RANGE_4G
led = WS2812.new(RMTDriver.new(27))

leds = [0] * LEDS

puts "3: init"

def calibrate(mpu)
  x = y = z = 0
  5.times do
    a = mpu.acceleration
    x += (a[:x] * 100).to_i
    y += (a[:y] * 100).to_i
    z += (a[:z] * 100).to_i
    sleep_ms 200
  end
  [x/5, y/5, z/5]
end

def accel_color(dx, dy, dz)
  r = (200 + dz).clamp(50, 255)
  g = (200 + dy).clamp(50, 255)  
  b = (200 + dx).clamp(50, 255)
  (r << 16) | (g << 8) | b
end

def show_bash(led, leds)
  ROWS.times do |r|
    COLS.times do |c|
      hex = BASE_BASH[r][c]
      leds[r*COLS+c] = ((hex>>16)&0xFF)/8.2<<16 | ((hex>>8)&0xFF)/8.2<<8 | (hex&0xFF)/8.2
    end
  end
  led.show_hex(*leds)
end

def show_char(led, char_bits, color, leds)
  LEDS.times { |i| leds[i] = 0 }
  bit = 1 << 24
  25.times do |i|
    leds[i] = color if (char_bits & bit) > 0
    bit >>= 1
  end
  led.show_hex(*leds)
end

puts "4: func"

nx, ny, nz = calibrate(mpu)
puts "5: cal"

last_btn = 1
btn_wait = 0

loop do
  puts "6: loop"
  
  btn = button.read
  if last_btn == 1 && btn == 0 && btn_wait == 0
    nx, ny, nz = calibrate(mpu)
    btn_wait = 10
  end
  last_btn = btn
  btn_wait -= 1 if btn_wait > 0

  puts "7: bash"
  start = Time.now.to_f * 1000
  while (Time.now.to_f * 1000 - start) < 5000
    show_bash(led, leds)
    sleep_ms 100
  end

  puts "8: char"
  ['b', 'a', 's', 'h'].each do |c|
    a = mpu.acceleration
    dx = (a[:x] * 100).to_i - nx
    dy = (a[:y] * 100).to_i - ny
    dz = (a[:z] * 100).to_i - nz
    color = accel_color(dx, dy, dz)
    
    start = Time.now.to_f * 1000
    while (Time.now.to_f * 1000 - start) < 500
      show_char(led, CHARS[c], color, leds)
      sleep_ms 50
    end
  end
  puts "9: done"
end
