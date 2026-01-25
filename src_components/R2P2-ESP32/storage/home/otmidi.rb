DEBUG = false  # デバッグモード

require 'ws2812'
require 'gpio'
require 'irq'
require 'uart'

class DrumMachine
  MIDI_TX_PIN = 22
  MIDI_RX_PIN = 19
  DRUM_INTERVAL = 2     # ドラム発音間隔(ms)。小さくすると速く
  
  KICK = 36
  SNARE = 38
  CLAP = 39
  HI_HAT_CLOSE = 42
  HI_HAT_OPEN = 46
  HIGH_TOM = 50
  MID_TOM = 47
  LOW_TOM = 41
  CRASH = 49
  
  PATTERN = [
    KICK, HI_HAT_CLOSE, SNARE, HI_HAT_CLOSE,
    KICK, HI_HAT_CLOSE, SNARE, HI_HAT_OPEN,
    KICK, MID_TOM, SNARE, HI_HAT_CLOSE,
    KICK, CLAP, SNARE, LOW_TOM
  ]
  
  GT = {36=>1, 38=>2, 39=>3, 49=>5, 52=>5}
  
  def initialize(uart)
    @uart = uart
    @step = 0
    @group_history = [1, 1, 1]
  end
  
  def update
    note = PATTERN[@step % PATTERN.size]
    @uart.write((0x99).chr + note.chr + (0x60).chr)
    
    g = GT[note] || 4
    if g != 5
      @group_history.shift
      @group_history.push(g)
    end
    @step += 1
  end
  
  def group_history
    @group_history
  end

  def step
    @step
  end
  
  def crash
    @uart.write((0x99).chr + CRASH.chr + (0x7F).chr)
  end
end

class RhythmLEDVisualizer
  LED_PIN = 32
  LED_COUNT = 30
  
  HUES_DRUM = [nil, 0, 128, 192, 64, 0]
  
  def initialize(led_strip)
    @led_strip = led_strip
    @led_colors = Array.new(LED_COUNT, 0)
  end
  
  def update(group_history, step)
    # ステップに基づいてオフセットを計算（毎拍ひとつずつシフト）
    pattern_offset = step % LED_COUNT

    saturation = 255
    brightness = 80
    sb = (saturation << 8) | brightness

    # 全 LED に対して group_history の色を循環させる
    LED_COUNT.times do |i|
      # 各 LED にオフセット付きで group_history から色を選ぶ
      color_idx = (i + pattern_offset) % group_history.size
      g = group_history[color_idx]
      hue = HUES_DRUM[g]

      @led_colors[i] = (hue << 16) | sb
    end
  end
  
  def show
    @led_strip.show_hsb_hex(*@led_colors)
  end
  
  def flash
    @led_strip.flash!(LED_COUNT)
  end
end

button = GPIO.new(39, GPIO::IN|GPIO::PULL_UP)
led_strip = WS2812.new(RMTDriver.new(RhythmLEDVisualizer::LED_PIN))

md_uart = UART.new(unit: :ESP32_UART1, baudrate: 31250, txd_pin: DrumMachine::MIDI_TX_PIN, rxd_pin: DrumMachine::MIDI_RX_PIN)
sleep_ms(10)
md_uart.clear_rx_buffer

md_uart.write((0xB9).chr + (32).chr + (16).chr)
sleep_ms(10)
md_uart.write((0xC9).chr + (0).chr)
sleep_ms(10)

drum = DrumMachine.new(md_uart)
led_viz = RhythmLEDVisualizer.new(led_strip)

irq = button.irq(GPIO::EDGE_FALL, debounce: 100, capture: {drum: drum, viz: led_viz}) do |btn, ev, cap|
  cap[:drum].crash
  cap[:viz].flash
end

tick_count = 0

loop do
  IRQ.process
  tick_count += 1
  
  if tick_count % DrumMachine::DRUM_INTERVAL == 0
    drum.update
  end

  led_viz.update(drum.group_history, drum.step)
  led_viz.show
  sleep_ms(85)
end

irq.unregister
