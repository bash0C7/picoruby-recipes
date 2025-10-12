require 'ws2812'
require 'gpio'
require 'irq'

class Button
  HIGH = 1
  LOW = 0
  
  def irq_instance
    @irq_instance
  end 

  def initialize(pin, cap = nil)
    @gpio = GPIO.new(pin, GPIO::IN|GPIO::PULL_UP)
    nullproc = Proc.new {}
    @on_press_callback = nullproc
    @on_release_callback = nullproc
    @press_count = 0
    @release_count = 0

#    @irq_instance = @gpio.irq(GPIO::EDGE_FALL | GPIO::EDGE_RISE, debounce: 50, capture: "My IRQ") do |peripheral, event_type, capture|
#    @irq_instance = @gpio.irq(GPIO::EDGE_FALL, debounce: 50, capture: "My IRQ") do |peripheral, event_type, capture|
    begin
      @irq_instance = @gpio.irq(GPIO::EDGE_FALL|GPIO::EDGE_RISE, debounce: 500, capture: cap) do |peripheral, event_type, capture|
        puts "=======start=========="
        puts "#{capture} -- Button! Event: #{event_type} EventClass: #{event_type.class}"
        puts "case when..."
        case event_type
        when 4 #EDGE_FALL = 4
          puts "fall!"
          puts @press_count
          @press_count += 1
          puts "counted"
          @on_press_callback&.call @press_count, peripheral, event_type, capture
          puts @press_count
        when 8 #EDGE_RISE = 8
          puts "rise!"
          puts @release_count
          @release_count += 1
          puts "counted"
          @on_release_callback&.call @release_count, peripheral, event_type, capture
          puts @release_count
        else
          puts event_type
        end
        puts "=======end=========="
      end
    rescue => e
      puts e.message
    end
  end
  
  def on_press(&callback)
    @on_press_callback = callback
    puts "on_press registered"
  end

  def on_release(&callback)
    @on_release_callback = callback
    puts "on_release registered"
  end

end

# うっすら色
rgb = {r: 5, g: 5, b: 5}

button = Button.new(39, rgb)
button.on_press do |count, peripheral, event_type, capture|
  puts "call on press: #{count}"
# 煌びやか色
  capture[:r] = 250
  capture[:g] = 130
  capture[:b] = 0
end

button.on_release do |count, peripheral, event_type, capture|
  puts "call on release: #{count}"
# オレンジ色設定（安全な輝度30）
  capture[:r] = 30
  capture[:g] = 15
  capture[:b] = 0
end

# LED設定
led_pin = 27
led_count = 25

puts "Setting all LEDs to orange color..."

# 色配列初期化
colors = Array.new(led_count) { [rgb[:r], rgb[:g], rgb[:b]] }

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
    colors[i] = [rgb[:r], rgb[:g], rgb[:b]]
  end
  
  # LED表示更新
  led.show_rgb(*colors)
  
  puts count
  sleep_ms 50  # 100ms間隔で更新
end
