
# ATOM Matrix外付けLED光源ペンライト
# 
# ATOM Matrixの外付け60 LEDストリップ(MAX90個)を光源として使用
# 100cmのアクリル透明筒にトレーシングペーパーを巻いたペンライト演出
# 光を拡散させて柔らかい照明効果を実現
# WS2812 LED strip connected to J5 port (G22)
# Using picoruby-ws2812 gem

require 'ws2812'
require 'i2c'
require 'vl53l0x'

puts "ATOM Matrix Internal LED Starting..."

# LED設定
led_pin = 22
led_count = 90

# WS2812初期化
led = WS2812.new(RMTDriver.new(led_pin))

i2c = I2C.new(
  unit: :ESP32_I2C0,
  frequency: 100_000,
  sda_pin: 25,    # PortB SDA
  scl_pin: 21,    # PortB SCL
  timeout: 2000
)
vl53l0x = VL53L0X.new(i2c)
# Check sensor initialization
if vl53l0x.ready?
  puts "VL53L0X sensor initialized successfully"
else
  puts "Failed to initialize VL53L0X sensor"
  puts "Check connections:"
  puts "  VCC -> 3.3V"
  puts "  GND -> GND" 
  puts "  SDA -> GPIO 25"
  puts "  SCL -> GPIO 21"
  exit
end

puts "LED initialized (GPIO #{led_pin}, #{led_count} LEDs)"

# オレンジ色設定
orange_r = 200
orange_g = 100
orange_b = 0


puts "Setting all LEDs to orange color..."

# 色配列初期化
colors = Array.new(led_count) { [orange_r, orange_g, orange_b] }

puts "Starting continuous LED display..."

# 連続点灯ループ
loop do
  distance = vl53l0x.read_distance
  brightness = distance > 0 ? ((2000 - distance) * 255.0 / 2000.0).to_i : 0

  # オレンジ色を保ちつつ明度変更
  led_count.times do |i|
    colors[i] = [
      (orange_r * brightness / 255.0).to_i,
      (orange_g * brightness / 255.0).to_i,
      (orange_b * brightness / 255.0).to_i
    ]
  end
  
  # LED表示更新
  led.show_rgb(*colors)
  
  sleep_ms 100  # 100ms間隔で更新
end
