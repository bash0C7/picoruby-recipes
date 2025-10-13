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
level_irq_instance = button.irq(GPIO::LEVEL_LOW| GPIO::LEVEL_HIGH, debounce: 100, capture: {led: led}) do |button, event, cap|
  # 💡 ブロック引数は event
  case event
  when GPIO::LEVEL_LOW
    puts "[LEVEL IRQ] Pin LOW. Toggling LED."
    cap[:led].toggle!
  when GPIO::LEVEL_LOW
    puts "[LEVEL IRQ] Pin HIGH."
  end
end

100.times do |i|
  puts i
  IRQ.process
  sleep_ms(50)
end

# --- STEP 4: Manual Event Processing Test ---

puts "\n--- STEP 4: Manual Event Processing Test ---"
puts "Testing IRQ.process(N) with limited event count."

level_irq_instance.unregister

# デバウンスを短く（10ms）してイベントを溜めやすくする
manual_irq_instance = button.irq(GPIO::EDGE_FALL | GPIO::EDGE_RISE, debounce: 10, capture: {led: led}) do |button, event, cap|
  case event
  when GPIO::EDGE_FALL
    puts "[Manual IRQ] FALL detected. Toggling LED."
    cap[:led].toggle!
  when GPIO::EDGE_RISE  
    puts "[Manual IRQ] RISE detected."
  end
end

# イベント蓄積フェーズ（3秒間）
puts "\n🔴 ACTION REQUIRED: Press button RAPIDLY 5-10 times within 3 seconds!"
puts "連打!!!!!!!!!!"
100.times do |i|
  puts i
  sleep_ms(50)
end
puts "\n✅ Time's up! Now processing events with limited count...\n"

# 最大3イベントだけ処理
puts "\n--- First batch: Processing up to 3 events ---"
processed_count = IRQ.process(3)
puts "✅ Processed #{processed_count} events (expected: 0-3)"

sleep_ms(500)

# 残りのイベントを処理
puts "\n--- Second batch: Processing remaining events ---"
remaining_count = IRQ.process(10)
puts "✅ Processed #{remaining_count} remaining events"

sleep_ms(500)

# 全イベント処理を確認
puts "\n--- Third batch: Confirming queue is empty ---"
final_count = IRQ.process(10)
puts "✅ Processed #{final_count} events (expected: 0)"

manual_irq_instance.unregister

puts "\n🎉 All Tests Complete!"
