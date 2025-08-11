# VBT LED Display - Memory Efficient Omnidirectional
# Proper 3-axis calculation without sqrt, maximum memory efficiency

# Round method for PicoRuby
class Float
  def round(digits = 0)
    if digits == 0
      if self >= 0
        (self + 0.5).to_i
      else
        (self - 0.5).to_i
      end
    else
      factor = 10.0 ** digits
      ((self * factor) + (self >= 0 ? 0.5 : -0.5)).to_i / factor.to_f
    end
  end
end

# Initialize I2C
require 'i2c'
i2c = I2C.new(
  unit: :ESP32_I2C0,
  frequency: 100_000,
  sda_pin: 25,
  scl_pin: 21
)

puts "VBT Start"
# Initialize LCD
[0x38, 0x39, 0x14, 0x70, 0x54, 0x6c].each { |i| i2c.write(0x3e, 0, i); sleep_ms 1 }
[0x38, 0x0c, 0x01].each { |i| i2c.write(0x3e, 0, i); sleep_ms 1 }

# Initialize MPU6886
require 'mpu6886'
mpu = MPU6886.new(i2c)
mpu.accel_range = MPU6886::ACCEL_RANGE_8G

# Initialize WS2812 - GPIO27 for ATOM Matrix
require 'rmt'

class WS2812
  def initialize(pin)
    @rmt = RMT.new(
      pin,
      t0h_ns: 350,
      t0l_ns: 800,
      t1h_ns: 700,
      t1l_ns: 600,
      reset_ns: 60000)
  end

  def show(*colors)
    bytes = []
    colors.each do |color|
      r, g, b = parse_color(color)
      bytes << g << r << b
    end
    @rmt.write(bytes)
  end

  def parse_color(color)
    if color.is_a?(Integer)
      [(color>>16)&0xFF, (color>>8)&0xFF, color&0xFF]
    else
      color
    end
  end
end
leds = WS2812.new(27)

# Pre-allocate LED array - REUSE to avoid memory allocation
led_data = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

# Colors - Ultra low brightness
orange = 0x100800
skyblue = 0x000C10
cyan = 0x001010

# Quick gravity calibration - use squared values to avoid sqrt
puts "Cal"
g_squared = 0.0
5.times do
  acc = mpu.acceleration
  # Calculate x²+y²+z² (3-axis magnitude squared)
  g_squared = g_squared + (acc[:x] * acc[:x] + acc[:y] * acc[:y] + acc[:z] * acc[:z])
  sleep_ms 20
end
gravity_squared = g_squared / 5.0  # Average gravity squared (~1.0²)

# Motion threshold squared (0.15G)² = 0.0225
threshold_squared = 0.0225

# Variables - minimal set
max_accel = 0.0
max_vel = 0.0
current_vel = 0.0

puts "Start"

# Main loop - memory optimized with proper physics
loop do
  # Get acceleration and calculate magnitude squared
  acc = mpu.acceleration
  acc_squared = acc[:x] * acc[:x] + acc[:y] * acc[:y] + acc[:z] * acc[:z]
  
  # Motion detection using squared values (avoids sqrt)
  if acc_squared > (gravity_squared + threshold_squared)
    # Calculate net acceleration magnitude (approximate)
    # Use simple approximation: if acc² > gravity², then net ≈ (acc² - gravity²) / (2 * gravity_estimate)
    net_acc_approx = (acc_squared - gravity_squared) / 2.0  # Rough approximation
    net_acc_ms2 = net_acc_approx * 9.81
    
    # Simple velocity integration
    current_vel = current_vel + net_acc_ms2 * 0.2
    
    # Update maximums
    max_accel = net_acc_ms2 if net_acc_ms2 > max_accel
    max_vel = current_vel if current_vel > max_vel
  end
  
  # Calculate LEDs - Arduino scaling
  accel_leds = (max_accel * 0.25).to_i
  accel_leds = 10 if accel_leds > 10
  vel_leds = (max_vel * 5.0).to_i
  vel_leds = 10 if vel_leds > 10
  
  # Clear LED array efficiently
  i = 0
  while i < 25
    led_data[i] = 0
    i = i + 1
  end
  
  # Set acceleration LEDs (rows 0-1)
  i = 0
  while i < accel_leds
    led_data[i] = orange
    i = i + 1
  end
  
  # Set velocity LEDs (rows 2-3)
  i = 0
  while i < vel_leds
    led_data[10 + i] = skyblue
    i = i + 1
  end
  
  # Set number (bottom right)
  led_data[24] = cyan
  
  # Update LEDs
  leds.show(*led_data)
  
  # Minimal debug
  puts "#{max_accel.round(1)},#{max_vel.round(1)}"
  
  sleep_ms 200
end