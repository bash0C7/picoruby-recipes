require 'irq'
require 'ws2812'

button = GPIO.new(39, GPIO::IN|GPIO::PULL_UP)

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

  def r!
    @toggle_count = 1
    toggle!
  end

  def b!
    @toggle_count = 0
    toggle!
  end
end

led = Led.new(22, 60)

irq = button.irq(GPIO::EDGE_FALL, debounce: 100, capture: {led: led}) do |button, event, cap|
  puts "Button pressed, toggling LED"
  cap[:led].toggle!
end

# Main loop
100.times do |i|
  puts i
  IRQ.process
  sleep_ms(50)
end

irq.unregister


# TEST 6
puts "\nT6"
puts "hold"

state = {pressing: false}

irq6 = button.irq(GPIO::EDGE_FALL | GPIO::EDGE_RISE, debounce: 50, 
                  capture: {led: led, state: state}) do |btn, ev, cap|
  case ev
  when GPIO::EDGE_FALL
    cap[:state][:pressing] = true
    puts "s"
  when GPIO::EDGE_RISE
    cap[:state][:pressing] = false
    puts "e"
  end
end

led.b!
100.times do |i|
  puts i if i % 20 == 0
  
  IRQ.process
  
  if state[:pressing]
    led.r!
    puts "h"
  else
    state[:pressing] = false
    led.b!
  end
  
  sleep_ms(50)
end

irq6.unregister
puts "T6ok"
