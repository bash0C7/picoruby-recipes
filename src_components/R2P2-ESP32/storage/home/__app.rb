# VBT Memory Optimized - PicoRuby
# Ultra minimal implementation to avoid out of memory errors

require 'i2c'
require 'mpu6886'
require 'rmt'
require "uart"

# Initialize devices
uart = UART.new(unit: :ESP32_UART0, baudrate: 115200)
i = I2C.new(unit: :ESP32_I2C0, frequency: 100_000, sda_pin: 25, scl_pin: 21)
m = MPU6886.new(i)
m.accel_range = MPU6886::ACCEL_RANGE_4G

# Memory optimized WS2812 class
class WS2812
  def initialize(pin)
    @rmt = RMT.new(pin, t0h_ns: 350, t0l_ns: 800, t1h_ns: 700, t1l_ns: 600, reset_ns: 60000)
  end

  # Direct LED control without array allocation
  def show(colors)
    bytes = []
    colors.each do |color|
      # Convert RGB to GRB format with reduced brightness
      r = ((color >> 16) & 0xFF) >> 3
      g = ((color >> 8) & 0xFF) >> 3
      b = (color & 0xFF) >> 3
      bytes << g << r << b
    end
    @rmt.write(bytes)
  end
end

w = WS2812.new(27)

# Pre-allocated LED array - REUSE to avoid memory allocation
led_data = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

# Cross pattern positions (center cross)
cross_positions = [7, 11, 12, 13, 17]

# Calibration - use simple variables
sx_sum = 0
sy_sum = 0
calibration_count = 5

# Calibration loop
while calibration_count > 0
  a = m.acceleration
  sx_sum = sx_sum + (a[:x] * 100).to_i
  sy_sum = sy_sum + (a[:y] * 100).to_i
  calibration_count = calibration_count - 1
  sleep_ms 200
end

nx = sx_sum / 5
ny = sy_sum / 5

# Simple variables to avoid complex objects
prev_sx = 0
prev_sy = 0
deadzone = 8
gentle_threshold = 25
current_color = 0xFF0000  # Red

uart.puts "VBT Ready"

loop do
  # Handle serial input
  input = uart.read
  if input == "red"
    current_color = 0xFF0000
    uart.puts "RED"
  elsif input == "green"
    current_color = 0x00FF00
    uart.puts "GREEN"
  elsif input == "blue"
    current_color = 0x0000FF
    uart.puts "BLUE"
  elsif input == "quit"
    uart.puts "QUIT"
    break
  end

  # Get acceleration data
  a = m.acceleration
  raw_x = (a[:x] * 100).to_i - nx
  raw_y = (a[:y] * 100).to_i - ny

  # Calculate motion intensity without complex operations
  motion_x_sq = raw_x * raw_x
  motion_y_sq = raw_y * raw_y
  motion_intensity = motion_x_sq + motion_y_sq

  # Motion processing - simplified logic
  deadzone_sq = deadzone * deadzone
  if motion_intensity < deadzone_sq
    sx = prev_sx
    sy = prev_sy
  else
    # Simple scale calculation
    gentle_sq = gentle_threshold * gentle_threshold
    if motion_intensity < gentle_sq
      scale = 80
    else
      scale = 15
    end

    # Calculate new positions with simple bounds checking
    new_sx = raw_x / scale
    new_sy = raw_y / scale

    # Clamp values manually
    sx = new_sx
    if sx > 4
      sx = 4
    end
    if sx < -4
      sx = -4
    end

    sy = new_sy
    if sy > 4
      sy = 4
    end
    if sy < -4
      sy = -4
    end

    prev_sx = sx
    prev_sy = sy
  end

  # Clear LED array efficiently
  i = 0
  while i < 25
    led_data[i] = 0
    i = i + 1
  end

  # Set cross pattern with bounds checking
  pos_index = 0
  while pos_index < 5
    p = cross_positions[pos_index]
    led_x = (p % 5) + sx
    led_y = (p / 5) + sy

    # Manual bounds checking
    if led_x >= 0 && led_x < 5 && led_y >= 0 && led_y < 5
      led_index = led_y * 5 + led_x
      led_data[led_index] = current_color
    end
    
    pos_index = pos_index + 1
  end

  # Update LEDs
  w.show(led_data)
  sleep_ms 50
end
