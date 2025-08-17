
# ATOM Matrix外付けLED光源ペンライト
# WS2812 LED strip connected to J5 port (G22)

require 'ws2812'
require 'i2c'
require 'vl53l0x'

led_pin = 22
led_count = 90

led = WS2812.new(RMTDriver.new(led_pin))

vl53l0x = VL53L0X.new(I2C.new(
  unit: :ESP32_I2C0,
  frequency: 100_000,
  sda_pin: 25,
  scl_pin: 21,
  timeout: 2000
))

unless vl53l0x.ready?
  puts "Failed to initialize VL53L0X sensor"
end

# 自然なオレンジ色（RGB比率を保持）
orange_r = 200
orange_g = 100  # 30→100に増加
orange_b = 0

colors = Array.new(led_count) { [0, 0, 0] }

loop do
  distance = vl53l0x.read_distance
  brightness = distance > 0 ? ((2000 - distance) * 255.0 / 2000.0).to_i : 0
  puts "Distance: #{distance}mm, Brightness: #{brightness}"

  # RGB全体に明度適用（色比率を保持）
  led_count.times do |i|
    colors[i] = [orange_r, orange_g, orange_b].map { |c| (c * brightness / 255.0).to_i }
  end
  
  led.show_rgb(*colors)
  sleep_ms 100
end