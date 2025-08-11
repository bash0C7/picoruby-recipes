require 'rmt'

class WS2812
  def initialize(pin, brightness = 1.0)
    @rmt = RMT.new(
      pin,
      t0h_ns: 350,
      t0l_ns: 800,
      t1h_ns: 700,
      t1l_ns: 600,
      reset_ns: 60000)
    @brightness = brightness
  end

  # Set brightness (0.0 to 1.0)
  def brightness=(value)
    @brightness = [[value, 0.0].max, 1.0].min
  end

  def brightness
    @brightness
  end

  # Show colors with current brightness
  def show(*colors)
    bytes = []
    colors.each do |color|
      r, g, b = parse_color(color)
      # Apply brightness scaling
      r = (r * @brightness).to_i
      g = (g * @brightness).to_i
      b = (b * @brightness).to_i
      bytes << g << r << b
    end
    @rmt.write(bytes)
  end

  # Show hexadecimal colors
  def show_hex(*hex_colors)
    show(*hex_colors)
  end

  # Show RGB array colors
  def show_rgb(*rgb_colors)
    show(*rgb_colors)
  end

  private

  def parse_color(color)
    if color.is_a?(Integer)
      [(color>>16)&0xFF, (color>>8)&0xFF, color&0xFF]
    else
      color
    end
  end
end

# Initialize with 1/8 brightness (0.125)
leds = WS2812.new(27, 0.125)

# Example 1: Heart pattern with dimmed red
leds.show_hex(
  0x000000, 0xFF0000, 0xFF0000, 0xFF0000, 0x000000,
  0xFF0000, 0xFF0000, 0xFF0000, 0xFF0000, 0xFF0000,
  0x000000, 0xFF0000, 0xFF0000, 0xFF0000, 0x000000,
  0x000000, 0x000000, 0xFF0000, 0x000000, 0x000000,
  0x000000, 0x000000, 0x000000, 0x000000, 0x000000)

# Example 2: Gradient from red to blue with dimmed colors
colors = []
(0..24).each do |i|
  r = (255 * (24 - i) / 24).to_i
  b = (255 * i / 24).to_i
  colors << [r, 0, b]
end
leds.show_rgb(*colors)

# Alternative: Manual brightness control
# leds.brightness = 0.125  # Set to 1/8 brightness
# leds.show_hex(0xFF0000, 0x00FF00, 0x0000FF)  # Will be displayed at 1/8 brightness
