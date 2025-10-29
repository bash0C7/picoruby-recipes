require 'irq'

gpio = GPIO.new(39, GPIO::IN|GPIO::PULL_UP)  # GPIO pin

# Register IRQ handler for falling edge
irq_instance = gpio.irq(GPIO::EDGE_FALL, capture: "My IRQ") do |peripheral, event_type, capture|
  puts "#{capture} -- Button pressed! Event: #{event_type}"
end

# Process IRQ events in main loop
200.times do |i|
  count = IRQ.process  # Process up to 5 events
  sleep_ms(10)
end

irq_instance.unregister

# Register IRQ with 50ms debounce to filter out button bounce
irq_instance = gpio.irq(GPIO::EDGE_FALL, debounce: 50) do |peripheral, event_type|
  puts "Debounced button press detected"
end

# Process IRQ events in main loop
200.times do |i|
  count = IRQ.process  # Process up to 5 events
  sleep_ms(10)
end


irq_instance.unregister

# Handle low level (useful for active-low sensors)
irq_instance = gpio.irq(GPIO::LEVEL_LOW) do |peripheral, event_type|
  puts "Sensor active"
end

# Process IRQ events in main loop
200.times do |i|
  count = IRQ.process  # Process up to 5 events
  sleep_ms(10)
end

# Check if IRQ is enabled
puts irq_instance.enabled?  # => true

# Temporarily disable IRQ
previous_state = irq_instance.disable
puts irq_instance.enabled?  # => false

# Re-enable IRQ
irq_instance.enable
puts irq_instance.enabled?  # => true
