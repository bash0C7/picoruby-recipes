require 'ws2812'
require 'gpio'
require 'irq'

class Button
  HIGH = 1
  LOW = 0
  
  def irq_instance
    @irq_instance
  end 

  def initialize(pin)
#    @gpio = GPIO.new(pin, GPIO::IN|GPIO::PULL_UP)
    @gpio = GPIO.new(pin, GPIO::IN)
    @on_press_callback = Proc.new {|count| }
    @on_release_callback = Proc.new {|count| }
    @press_count = 0
    @release_count = 0

#    @irq_instance = @gpio.irq(GPIO::EDGE_FALL | GPIO::EDGE_RISE, debounce: 50, capture: "My IRQ") do |peripheral, event_type, capture|
#    @irq_instance = @gpio.irq(GPIO::EDGE_FALL, debounce: 50, capture: "My IRQ") do |peripheral, event_type, capture|
    @irq_instance = @gpio.irq(GPIO::EDGE_FALL | GPIO::EDGE_RISE, debounce: 500, capture: {pin: pin}) do |peripheral, event_type, capture|
      puts "#{capture[:pin]} -- Button pressed! Event: #{event_type}"
      case event_type
      when GPIO::EDGE_FALL
        puts "fall"
        press_count += 1
        @on_press_callback.call @press_count
      when GPIO::EDGE_RISE  
        puts "rise"
        release_count += 1
        @on_release_callback.call @release_count
      end
    end
  end
  
  def on_press(&block)
    @on_press_callback = block
  end

  def on_release(&block)
    @on_release_callback = block
  end

end

# うっすら色
orange_r = 5
orange_g = 5
orange_b = 5

button = Button.new(39)
button.on_press do |count|
  puts "call on press"
# 煌びやか色
  orange_r = 250
  orange_g = 130
  orange_b = 0
end

button.on_release do |count|
  puts "call on release"
# オレンジ色設定（安全な輝度30）
  orange_r = 30
  orange_g = 15
  orange_b = 0
end

# LED設定
led_pin = 27
led_count = 25

puts "Setting all LEDs to orange color..."

# 色配列初期化
colors = Array.new(led_count) { [orange_r, orange_g, orange_b] }

puts "Starting continuous LED display..."

# WS2812初期化
led = WS2812.new(RMTDriver.new(led_pin))

puts "LED initialized (GPIO 27, 25 LEDs)"

# 連続点灯ループ
loop do
  count = IRQ.process
  #puts count
  #puts button.irq_instance.enabled?  # => true
  # 毎回色を設定してLED更新
  led_count.times do |i|
    colors[i] = [orange_r, orange_g, orange_b]
  end
  
  # LED表示更新
  led.show_rgb(*colors)
  
  sleep_ms 50  # 100ms間隔で更新
end
