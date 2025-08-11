# J5 LED Strip Control - 60 LEDs Orange Light
# WS2812 LED strip connected to J5 port (G19 or G22)
# Using picoruby-ws2812 gem

require 'ws2812'

puts "J5 LED Strip Controller Starting..."
puts "LED Count: 60"
puts "Color: Orange"

# J5 port GPIO configuration
# J5(PortD): G19(TX), G22(RX) - both can be used for digital output
# Using G19 for WS2812 control (adjust pin number as needed)
led_pin = 19  # or 22 depending on wiring

# Initialize WS2812 LED strip
led = WS2812.new(RMTDriver.new(led_pin))
puts "WS2812 initialized on GPIO #{led_pin}"

# LED configuration
led_count = 60
brightness = 50  # Safe brightness level (0-255)

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
puts "All LEDs should now be glowing orange"

# Keep LEDs on (infinite loop)
# Comment out this section if you want the program to end
puts "Press Ctrl+C to exit"
loop do
  sleep_ms 1000
end