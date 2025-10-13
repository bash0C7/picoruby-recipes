require 'irq'
require 'ws2812'

class Led
  def initialize(pin, count)
    @ws2812 = WS2812.new(RMTDriver.new(pin))
    @colors = Array.new(count)
    @toggle_count = 0
    @pattern = [
      {r: 30, g: 5, b: 0},
      {r: 0, g: 5, b: 30},
    ]
    toggle!
  end

  def toggle!
    @toggle_count += 1
    current = @toggle_count % 2
    @colors.size.times do |i|
      @colors[i] = [@pattern[current][:r], @pattern[current][:g], @pattern[current][:b]] 
    end
    @ws2812.show_rgb(*@colors)
  end
end

button = GPIO.new(39, GPIO::IN|GPIO::PULL_UP)
led = Led.new(27, 25)
puts "OK"

# TEST 1
puts "\nT1"

irq1 = button.irq(GPIO::EDGE_FALL | GPIO::EDGE_RISE, debounce: 100, capture: led) do |btn, ev, cap|
  case ev
  when GPIO::EDGE_FALL
    cap.toggle!
    puts "F"
  when GPIO::EDGE_RISE
    puts "R"
  end
end

100.times do |i|
  puts i if i % 20 == 0
  IRQ.process
  sleep_ms(50)
end

irq1.unregister
puts "T1ok"

# TEST 2
puts "\nT2"

irq2 = button.irq(GPIO::LEVEL_LOW | GPIO::LEVEL_HIGH, debounce: 100, capture: led) do |btn, ev, cap|
  case ev
  when GPIO::LEVEL_LOW
    cap.toggle!
    puts "L"
  when GPIO::LEVEL_HIGH
    puts "H"
  end
end

100.times do |i|
  puts i if i % 20 == 0
  IRQ.process
  sleep_ms(50)
end

irq2.unregister
puts "T2ok"

# TEST 3
puts "\nT3"

irq3 = button.irq(GPIO::EDGE_FALL | GPIO::EDGE_RISE | GPIO::LEVEL_LOW | GPIO::LEVEL_HIGH, 
                  debounce: 100, capture: led) do |btn, ev, cap|
  case ev
  when GPIO::EDGE_FALL
    cap.toggle!
    puts "F"
  when GPIO::EDGE_RISE
    puts "R"
  when GPIO::LEVEL_LOW
    puts "L!"
    raise "L"
  when GPIO::LEVEL_HIGH
    puts "H!"
    raise "H"
  end
end

100.times do |i|
  puts i if i % 20 == 0
  IRQ.process
  sleep_ms(50)
end

irq3.unregister
puts "T3ok"

# TEST 4
puts "\nT4"

irq4 = button.irq(GPIO::EDGE_FALL, debounce: 50, capture: led) do |btn, ev, cap|
  cap.toggle!
  puts "Fa"
end

50.times do |i|
  puts i if i % 20 == 0
  IRQ.process
  sleep_ms(50)
end

irq4.unregister
puts "un"

sleep_ms(500)

irq4 = button.irq(GPIO::EDGE_RISE, debounce: 50, capture: led) do |btn, ev, cap|
  cap.toggle!
  puts "Rb"
end

50.times do |i|
  puts i if i % 20 == 0
  IRQ.process
  sleep_ms(50)
end

irq4.unregister
puts "T4ok"

# TEST 5
puts "\nT5"
puts "5+"

irq5 = button.irq(GPIO::EDGE_FALL | GPIO::EDGE_RISE, debounce: 10, capture: led) do |btn, ev, cap|
  cap.toggle!
  puts "e"
end

60.times do |i|
  puts i if i % 20 == 0
  sleep_ms(50)
end

puts "p3"
cnt = IRQ.process(3)
puts cnt

sleep_ms(500)

puts "p10"
cnt = IRQ.process(10)
puts cnt

sleep_ms(500)

puts "p10"
cnt = IRQ.process(10)
puts cnt

irq5.unregister
puts "T5ok"
