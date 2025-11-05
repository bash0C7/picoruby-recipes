require 'irq'
require 'ws2812'

gpio = GPIO.new(39, GPIO::IN|GPIO::PULL_UP)  # GPIO pin

class Led
  def initialize(pin, count)
    @ws2812 = WS2812.new(RMTDriver.new(pin))
    @colors = Array.new(count)

    neutral!
  end

  def neutral!
    @colors.size.times do |i|
      @colors[i] = [5, 10, 5] 
    end
    @ws2812.show_rgb(*@colors)
  end

  def active!
    @colors.size.times do |i|
      @colors[i] = [50, 5, 5] 
    end
    @ws2812.show_rgb(*@colors)
  end

  def deactive!
    @colors.size.times do |i|
      @colors[i] = [5, 5, 50] 
    end
    @ws2812.show_rgb(*@colors)
  end

  def off!
    @colors.size.times do |i|
      @colors[i] = [0, 0, ] 
    end
    @ws2812.show_rgb(*@colors)
  end
end
led = Led.new(27, 25)

puts "Basic GPIO IRQ"

irq_instance = gpio.irq(GPIO::EDGE_FALL, capture: "My IRQ") do |peripheral, event_type, capture|
  puts "#{capture} -- Button pressed! Event: #{event_type}"
  led.active!
end

30.times do |i|
  puts i if i % 5 == 0
  IRQ.process
  sleep_ms(100)
  led.neutral!
end

puts "IRQ with Debouncing"
irq_instance.unregister

irq_instance = gpio.irq(GPIO::EDGE_FALL, debounce: 50) do |peripheral, event_type|
  puts "Debounced button press detected"
  led.active!
end

30.times do |i|
  puts i if i % 5 == 0
  IRQ.process
  sleep_ms(100)
  led.neutral!
end

puts "Multiple Event Types"

irq_instance = gpio.irq(GPIO::EDGE_FALL | GPIO::EDGE_RISE) do |peripheral, event_type, capture|
  case event_type
  when GPIO::EDGE_FALL
    puts "Button pressed"
    led.active!
  when GPIO::EDGE_RISE  
    puts "Button released"
    led.deactive!
  end
end

30.times do |i|
  puts i if i % 5 == 0
  IRQ.process
  sleep_ms(100)
end

puts "Level-Triggered IRQs"
irq_instance.unregister

irq_instance = gpio.irq(GPIO::LEVEL_LOW) do |peripheral, event_type|
  puts "Sensor active"
  led.active!
end

30.times do |i|
  puts i if i % 5 == 0
  IRQ.process 
  sleep_ms(100)
  led.neutral!
end

puts "IRQ Management"

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

puts "Manual Event Processing"
irq_instance.unregister

irq_instance = gpio.irq(GPIO::EDGE_FALL | GPIO::EDGE_RISE) do |peripheral, event_type, capture|
  case event_type
  when GPIO::EDGE_FALL
    puts "Button pressed"
    led.active!
  when GPIO::EDGE_RISE  
    puts "Button released"
    led.deactive!
  end
end

5.times do |i|
  puts i if i % 5 == 0
  count = IRQ.process(3)
  puts "Processed #{count} events"
  sleep_ms(1000)
end

led.off!