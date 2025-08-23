require 'ws2812'

led = WS2812.new(RMTDriver.new(27))

buffer = []
25.times { buffer << 0x000000 }

bash_pattern = [
  [219, 180, 139], [227, 188, 142], [202, 44, 18], [185, 92, 71], [224, 180, 137],
  [224, 74, 13], [253, 121, 16], [243, 0, 11], [249, 0, 7], [251, 122, 16],
  [195, 114, 96], [210, 48, 6], [198, 0, 4], [242, 80, 13], [239, 101, 27],
  [252, 231, 192], [218, 62, 5], [250, 196, 118], [220, 25, 11], [204, 138, 91],
  [212, 0, 4], [241, 0, 9], [197, 32, 6], [239, 0, 7], [140, 0, 3]
].map do |rgb|
  r, g, b = rgb
  ((r << 16) | (g << 8) | b)
end

patterns = [
  [[true, true, true, true, true,
    true, true, true, true, true,
    true, true, true, true, true,
    true, true, true, true, true,
    true, true, true, true, true], 5000],
  [[true, true, true, true, false,
    true, false, false, false, true,
    true, true, true, true, false,
    true, false, false, false, true,
    true, true, true, true, false], 500],
  [[false, true, true, true, false,
    true, false, false, false, true,
    true, true, true, true, true,
    true, false, false, false, true,
    true, false, false, false, true], 500],
  [[false, true, true, true, true,
    true, false, false, false, false,
    false, true, true, true, false,
    false, false, false, false, true,
    true, true, true, true, false], 500],
  [[true, false, false, false, true,
    true, false, false, false, true,
    true, true, true, true, true,
    true, false, false, false, true,
    true, false, false, false, true], 500]
].map do |bits, time|
  [bits.map { |x| x ? 0xffffff : 0x000000 }, time]
end

loop do
  patterns.each do |pattern, duration|
    bash_pattern.each_with_index do |b, i|
      buffer[i] = b & pattern[i]
    end
    
    led.show_hex(*buffer)
    sleep_ms duration
  end
end
