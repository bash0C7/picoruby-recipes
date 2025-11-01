require 'rmt'

class RMTDriver
  def initialize(pin, t0h_ns: 350, t0l_ns: 800, t1h_ns: 700, t1l_ns: 600, reset_ns: 60000)
    @rmt = RMT.new(
      pin,
      t0h_ns: t0h_ns,
      t0l_ns: t0l_ns,
      t1h_ns: t1h_ns,
      t1l_ns: t1l_ns,
      reset_ns: reset_ns
    )
  end

  def write(bytes)
    @rmt.write(bytes)
  end
end

class WS2812
  def initialize(driver)
    @driver = driver
  end

  def show_rgb(*colors)
    bytes = []
    colors.each do |color|
      r, g, b = color
      bytes << g << r << b
    end

    @driver.write(bytes)
  end

  def show_hex(*colors)
    bytes = []
    colors.each do |color|
      r, g, b = [(color>>16)&0xFF, (color>>8)&0xFF, color&0xFF]
      bytes << g << r << b
    end

    @driver.write(bytes)
  end

  def show_hsb(*colors)
    bytes = []
    colors.each do |color|
      h, s, b = color
      r, g, b = hsb_to_rgb(h, s, b)
      bytes << g << r << b
    end
    @driver.write(bytes)
  end

  def show_hsb_hex(*colors)
    bytes = []
    colors.each do |color|
      h = (color >> 16) & 0xFF
      s = (color >> 8) & 0xFF
      b = color & 0xFF
      r, g, b = hsb_to_rgb(h, s, b)
      bytes << g << r << b
    end
    @driver.write(bytes)
  end

  def flash!(num_leds)
    bytes = Array.new(num_leds * 3, 0xFF)
    @driver.write(bytes)
  end

  private

  def hsb_to_rgb(h, s, b)
    h &= 0xFF
    s = s > 255 ? 255 : s
    b = b > 255 ? 255 : b

    return [b, b, b] if s == 0

    region = h / 43
    remainder = (h - region * 43) * 6

    p = (b * (255 - s)) >> 8
    q = (b * (255 - ((s * remainder) >> 8))) >> 8
    t = (b * (255 - ((s * (255 - remainder)) >> 8))) >> 8

    case region
    when 0 then [b, t, p]
    when 1 then [q, b, p]
    when 2 then [p, b, t]
    when 3 then [p, q, b]
    when 4 then [t, p, b]
    else [b, p, q]
    end
  end
end
