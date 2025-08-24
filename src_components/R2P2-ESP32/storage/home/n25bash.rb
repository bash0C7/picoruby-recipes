require 'ws2812'

led = WS2812.new(RMTDriver.new(27))
#extled = WS2812.new(RMTDriver.new(32))

bash_pattern = [
  [175, 144, 111], [182, 150, 114], [162, 35, 14], [148, 74, 57], [179, 144, 110],
  [179, 59, 10], [202, 97, 13], [194, 0, 9], [199, 0, 6], [201, 98, 13],
  [156, 91, 77], [168, 38, 5], [158, 0, 3], [194, 64, 10], [191, 81, 22],
  [202, 185, 154], [174, 50, 4], [200, 157, 94], [176, 20, 9], [163, 110, 73],
  [170, 0, 3], [193, 0, 7], [158, 26, 5], [191, 0, 6], [112, 0, 2]
].map do |rgb|
  r, g, b = rgb
  ((r << 16) | (g << 8) | b)
end

buffer = Array.new(bash_pattern.size) { 0x000000 }

patterns = [
  [[true, true, true, true, true,
    true, true, true, true, true,
    true, true, true, true, true,
    true, true, true, true, true,
    true, true, true, true, true], 1000],
  [[true, false, false, false, false,
    true, false, false, false, false,
    true, true, true, false, false,
    true, false, false, true, false,
    true, true, true, false, false], 500],
  [[false, true, true, true, false,
    false, false, false, true, false,
    false, true, true, true, false,
    true, false, false, true, false,
    false, true, true, true, false], 500],
  [[false, true, true, true, false,
    true, false, false, false, false,
    false, true, true, false, false,
    false, false, false, true, false,
    true, true, true, false, false], 500],
  [[true, false, false, false, false,
    true, true, true, false, false,
    true, false, false, true, false,
    true, false, false, true, false,
    true, false, false, true, false], 500]
].map do |bits, time|
  [bits.map { |x| x ? 0xffffff : 0x000000 }, time]
end

loop do
  patterns.each do |pattern, duration|
    bash_pattern.each_with_index do |b, i|
      buffer[i] = b & pattern[i]
    end
    
    led.show_hex(*buffer)
#    extled.show_hex(*buffer)
    sleep_ms duration

    bash_pattern.each_with_index do |b, i|
      buffer[i] = 0x000000
    end
    led.show_hex(*buffer)
#    extled.show_hex(*buffer)
    sleep_ms 50
  end
end
