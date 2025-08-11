# VL53L0X ToF Distance Sensor - PortB Connection
# Unit ToF connected to expansion board PortB (G21:SCL, G25:SDA)
# Using picoruby-vl53l0x gem

require 'i2c'
require 'vl53l0x'

puts "VL53L0X ToF Distance Sensor Starting..."
puts "Connected to PortB (G21:SCL, G25:SDA)"

# Initialize I2C for PortB connection
# PortB uses the same pins as internal MPU6886 (shared I2C bus)
i2c = I2C.new(
  unit: :ESP32_I2C0,
  frequency: 100_000,
  sda_pin: 25,    # PortB SDA
  scl_pin: 21,    # PortB SCL
  timeout: 2000
)

puts "I2C initialized: ESP32_I2C0, SDA:25, SCL:21"

# Initialize VL53L0X sensor (default I2C address: 0x29)
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

puts "Starting distance measurements..."
puts "---"

# Continuous distance measurement loop
loop do
  distance = vl53l0x.read_distance
  
  if distance > 0
    # Display distance with status categorization
    status = case distance
             when 0..50
               "[Very Close]"
             when 51..200
               "[Close]"
             when 201..500
               "[Medium]"
             when 501..1000
               "[Far]"
             when 1001..2000
               "[Very Far]"
             else
               "[Out of Range]"
             end
    
    puts "Distance: #{distance}mm #{status}"
  else
    puts "Out of range or measurement error"
  end
  
  sleep_ms 200  # 200ms interval between measurements
end