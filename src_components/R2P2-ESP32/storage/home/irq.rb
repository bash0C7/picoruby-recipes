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
end

led = Led.new(27, 25)
puts "LED initialized."

# --- STEP 1: EDGE割り込みの登録とテスト ---

# 💡 割り込みインスタンスを変数にキャプチャ (必須)
edge_irq_instance = button.irq(GPIO::EDGE_FALL | GPIO::EDGE_RISE, debounce: 100, capture: {led: led}) do |button, event, cap|
  # 💡 ブロック引数は event
  case event
  when GPIO::EDGE_FALL
    puts "[EDGE IRQ] Button pressed (FALL). Toggling LED."
    cap[:led].toggle!
  when GPIO::EDGE_RISE  
    puts "[EDGE IRQ] Button released (RISE)."
  end
end

puts "\n--- STEP 1: EDGE IRQ Test Start (Check button press/release) ---"
100.times do |i|
  puts i
  IRQ.process
  sleep_ms(50)
end

# --- STEP 2: Unregisterの確認 ---

puts "\n--- STEP 2: Unregister Test ---"
puts "Unregistering EDGE IRQ (ID: #{edge_irq_instance.peripheral.pin})."
# 💡 unregister を実行
edge_irq_instance.unregister

# 割り込みが機能しないことを確認するためのループ
puts "Checking for residual EDGE events (Should be silent)..."
100.times do |i|
  puts i
  IRQ.process
  sleep_ms(50)
end

# --- STEP 3: LEVEL割り込みの再登録とテスト ---

puts "\n--- STEP 3: LEVEL IRQ Re-register Test (Check button state) ---"
# 💡 同じピンに対して別の割り込みを再登録
level_irq_instance = button.irq(GPIO::LEVEL_LOW | GPIO::LEVEL_HIGH, debounce: 100, capture: {led: led}) do |button, event, cap|
  # 💡 ブロック引数は event
  case event
  when GPIO::LEVEL_LOW
    puts "[LEVEL IRQ] Pin LOW."
  when GPIO::LEVEL_HIGH
    puts "[LEVEL IRQ] Pin HIGH."
  end
end

# Main loop (LEVEL割り込みテスト)
puts "Processing LEVEL IRQ events (Press/Hold/Release button quickly)."
100.times do |i|
  puts i
  IRQ.process
  sleep_ms(50)
end

# Main loop (processed_count)
puts "Processing processed_count."
100.times do |i|
  puts i
  processed_count = IRQ.process(10)  # Process up to 10 events at a time
  if processed_count > 0
    puts "Processed #{processed_count} LEVEL events."
  end
  sleep_ms(50)
end
