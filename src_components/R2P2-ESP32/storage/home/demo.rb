# Ruby Gemstone Demo - Pure LED Display (No LCD Dependencies)

require 'i2c'
require 'mpu6886'
require 'rmt'

# I2C setup for MPU6886 sensor only
i = I2C.new(unit: :ESP32_I2C0, frequency: 100_000, sda_pin: 25, scl_pin: 21)

# MPU6886 setup
m = MPU6886.new(i)
m.accel_range = MPU6886::ACCEL_RANGE_4G

# WS2812 minimal class
class WS2812
  def initialize(pin)
    @rmt = RMT.new(pin, t0h_ns: 350, t0l_ns: 800, t1h_ns: 700, t1l_ns: 600, reset_ns: 60000)
  end
  def show(colors)
    b = []
    colors.each do |x|
      r = ((x >> 16) & 0xFF) >> 3
      g = ((x >> 8) & 0xFF) >> 3
      blue = (x & 0xFF) >> 3
      b << g << r << blue
    end
    @rmt.write(b)
  end
end

w = WS2812.new(27)

# Pre-allocated LED array
l = []
25.times { l << 0 }

# New ruby pattern (more compact gemstone shape)
# Pattern: center diamond with smaller footprint
r = [7, 11, 12, 13, 17]  # 5 LEDs forming compact ruby

# Calibration phase - sensor only
sx = sy = 0
5.times do
  a = m.acceleration
  sx += (a[:x]*100).to_i
  sy += (a[:y]*100).to_i
  sleep_ms 200
end
nx = sx/5
ny = sy/5

# Motion control variables
prev_sx = 0
prev_sy = 0
deadzone = 8        # Minimum motion threshold to prevent flicker
gentle_threshold = 25   # Threshold for gentle vs dynamic movement

# Main loop with improved motion response
loop do
  a = m.acceleration
  raw_x = (a[:x]*100).to_i - nx
  raw_y = (a[:y]*100).to_i - ny
  
  # Calculate motion intensity
  motion_intensity = raw_x*raw_x + raw_y*raw_y
  
  # Apply deadzone and dynamic scaling
  if motion_intensity < (deadzone * deadzone)
    # Within deadzone - maintain previous position (no flicker)
    sx = prev_sx
    sy = prev_sy
  else
    # Outside deadzone - calculate movement with dynamic sensitivity
    if motion_intensity < (gentle_threshold * gentle_threshold)
      # Gentle movement - high damping for smooth motion
      scale = 80  # Much higher damping for subtle movement
    else
      # Strong movement - lower damping for dynamic response
      scale = 15  # Original sensitivity for dramatic movement
    end
    
    new_sx = raw_x / scale
    new_sy = raw_y / scale
    
    # Constrain movement range
    sx = new_sx > 4 ? 4 : new_sx < -4 ? -4 : new_sx
    sy = new_sy > 4 ? 4 : new_sy < -4 ? -4 : new_sy
    
    # Store position for next deadzone check
    prev_sx = sx
    prev_sy = sy
  end
  
  # Color selection based on motion intensity
  col = 0xFF0000  # Static red
  col = 0xFF4080 if motion_intensity > 600    # Pink for gentle motion
  col = 0x8040FF if motion_intensity > 2400   # Purple for active motion
  
  # Clear LED array
  25.times{|j| l[j] = 0}
  
  # Draw ruby at calculated position
  r.each do |p|
    led_x = p % 5 + sx
    led_y = p / 5 + sy
    
    # Only draw if within LED matrix bounds
    if led_x >= 0 && led_x < 5 && led_y >= 0 && led_y < 5
      l[led_y * 5 + led_x] = col
    end
  end
  
  w.show(l)
    
  sleep_ms 50
end
