require 'irq'
require 'ws2812'

gpio = GPIO.new(39, GPIO::IN|GPIO::PULL_UP)  # GPIO pin

class Led
  def initialize(pin, count)
    @ws2812 = WS2812.new(RMTDriver.new(pin))
    @colors = Array.new(count)

    @toggle_count = 0
    @pattern = [
      {r: 30, g: 5, b: 0},
      {r: 0, g: 5, b: 30},
    ]
    deactive!
  end

  def toggle!
    @toggle_count += 1
    current = @toggle_count % 2
    @colors.size.times do |i|
      @colors[i] = [@pattern[current][:r], @pattern[current][:g], @pattern[current][:b]] 
    end
    @ws2812.show_rgb(*@colors)
  end

  def active!
    @toggle_count = 1
    toggle!
  end

  def deactive!
    @toggle_count = 0
    toggle!
  end
end
led = Led.new(27, 25)

puts "-----------"

# Register IRQ handler for falling edge
irq_instance = gpio.irq(GPIO::EDGE_FALL, capture: "My IRQ") do |peripheral, event_type, capture|
  puts "#{capture} -- Button pressed! Event: #{event_type}"
  led.active!
end

# Process IRQ events in main loop
100.times do |i|
  puts i if i % 10 == 0
  count = IRQ.process  # Process up to 5 events
  sleep_ms(100)
  led.deactive!
end

puts "-----------"
irq_instance.unregister

# Register IRQ with 50ms debounce to filter out button bounce
irq_instance = gpio.irq(GPIO::EDGE_FALL, debounce: 50) do |peripheral, event_type|
  puts "Debounced button press detected"
  led.active!
end

# Process IRQ events in main loop
100.times do |i|
  puts i if i % 10 == 0
  count = IRQ.process  # Process up to 5 events
  sleep_ms(100)
  led.deactive!
end

puts "-----------"
irq_instance.unregister

# Handle low level (useful for active-low sensors)
irq_instance = gpio.irq(GPIO::LEVEL_LOW) do |peripheral, event_type|
  puts "Sensor active"
  led.active!
end

# Process IRQ events in main loop
100.times do |i|
  puts i if i % 10 == 0
  count = IRQ.process  # Process up to 5 events
  sleep_ms(100)
  led.deactive!
end

puts "-----------"

# Check if IRQ is enabled
puts irq_instance.enabled?  # => true

puts "-----------"

# Temporarily disable IRQ
previous_state = irq_instance.disable
puts previous_state # => true
puts irq_instance.enabled?  # => false

puts "-----------"

# Re-enable IRQ
previous_state = irq_instance.enable
puts previous_state # => false
puts irq_instance.enabled?  # => true
