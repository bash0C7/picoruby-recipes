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
    @ws2812 .show_rgb(*@colors)
  end
end

led = Led.new(27, 25)

button.irq(GPIO::EDGE_FALL, debounce: 100, capture: {led: led}) do |button, event, cap|
  puts "Button pressed, toggling LED"
  cap[:led].toggle!
end

# Main loop
loop do
  IRQ.process
  sleep_ms(50)
end
