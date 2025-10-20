require 'i2c'
require 'mpu6886'
require 'ws2812'
require 'uart'

puts "Start"

# I2C先に確保
i2c = I2C.new(unit: :ESP32_I2C0, frequency: 100_000, sda_pin: 25, scl_pin: 21)
sleep_ms(100)

# LED
led = WS2812.new(RMTDriver.new(22))
sleep_ms(100)

# UART
pc = UART.new(unit: :ESP32_UART0, baudrate: 115200)
sleep_ms(100)

md = UART.new(unit: :ESP32_UART1, baudrate: 31250, txd_pin: 26, rxd_pin: 32)
sleep_ms(100)

# MPU（i2c参照を保持）
mpu = MPU6886.new(i2c)
mpu.accel_range = MPU6886::ACCEL_RANGE_4G
sleep_ms(100)

# 色配列（実証済み形式）
co = Array.new(60) { 0xFF8040 }

puts "Cal"
sx = sy = sz = 0
5.times do |i|
  a = mpu.acceleration
  sx += (a[:x] * 100).to_i
  sy += (a[:y] * 100).to_i
  sz += (a[:z] * 100).to_i
  sleep_ms 100
end
bx = [sx / 5, sy / 5, sz / 5]

puts "Ready"

puts "Go"

loop do
  a = mpu.acceleration
  puts "X: #{(a[:x] * 100).to_i}"
  
  sleep_ms 500
end
