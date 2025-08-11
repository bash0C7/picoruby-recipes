# ATOM Matrix Internal 5x5 LED Control - Orange Light
# Built-in WS2812 LEDs connected to GPIO 26(ext grove)
# Using picoruby-ws2812 gem

require 'ws2812'

puts "ATOM Matrix Internal LED Controller Starting..."
puts "LED Count: 25 (5x5 matrix)"
puts "Color: Orange"

# ATOM Matrix ext LED connection(grove)
led_pin = 32

# Initialize WS2812 LED matrix
led = WS2812.new(RMTDriver.new(led_pin))
puts "WS2812 initialized on GPIO #{led_pin}"

# LED configuration
led_count = 25  # 5x5 = 25 LEDs
brightness = 30  # Lower brightness for internal LEDs to prevent overheating

# Orange color definition (RGB values)
orange_r = brightness
orange_g = (brightness * 0.5).to_i  # Half green for orange
orange_b = 0

puts "Orange RGB: #{orange_r}, #{orange_g}, #{orange_b}"

# Create color array for all LEDs
colors = Array.new(led_count) { [orange_r, orange_g, orange_b] }

puts "Setting all #{led_count} LEDs to orange..."

# Light up all LEDs in orange
led.show_rgb(*colors)

puts "LED control complete!"
puts "All internal LEDs should now be glowing orange"

# Keep LEDs on (infinite loop)
# Comment out this section if you want the program to end
puts "Press Ctrl+C to exit"
loop do
  sleep_ms 1000
end