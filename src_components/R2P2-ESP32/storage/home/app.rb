require 'uart'
require 'ws2812'
require 'irq'

LED_COUNT = 25 #LED個数
LED_PIN = 32 #ボードは22、本体外部は32、内蔵は27

GT = {36=>1, 38=>2, 39=>3, 49=>5, 52=>5}
HUES = [nil, 0, 128, 192, 64, 0]

# ドラムノート定義
KICK = 36
SNARE = 38
CLAP = 39
HI_HAT_CLOSE = 42
HI_HAT_OPEN = 46
HIGH_TOM = 50
MID_TOM = 47
LOW_TOM = 41

# 120bpm の 16ビートパターン
drum_pattern = [
  KICK, HI_HAT_CLOSE, SNARE, HI_HAT_CLOSE,
  KICK, HI_HAT_CLOSE, SNARE, HI_HAT_OPEN,
  KICK, MID_TOM, SNARE, HI_HAT_CLOSE,
  KICK, CLAP, SNARE, LOW_TOM
]

STEP_INTERVAL = 6

md_uart = UART.new(unit: :ESP32_UART1, baudrate: 31250, txd_pin: 23, rxd_pin: 33)
sleep_ms(10)

button = GPIO.new(39, GPIO::IN|GPIO::PULL_UP)
sleep_ms(10)

led_strip = WS2812.new(RMTDriver.new(LED_PIN))
led_colors = Array.new(LED_COUNT, 0xC0960A)
sleep_ms(10)

md_uart.clear_rx_buffer

# Bank Select LSB (CC#32) = 16 (Power Kit)
md_uart.write((0xB9).chr + (32).chr + (16).chr)
sleep_ms(10)

# Program Change = 0
md_uart.write((0xC9).chr + (0).chr)

tick_count = 0
step = 0
group_history = [1, 1, 1]
saturation = 168
brightness = 55
led_offset = 0

irq = button.irq(GPIO::EDGE_FALL, debounce: 100, capture: {md_uart: md_uart, led_strip: led_strip}) do |button, event, cap|
  puts "BUTTON!"
  cap[:md_uart].write((0x99).chr + 49.chr + (0x7F).chr)
  cap[:led_strip].flash!(led_colors.size)
end

loop do
  IRQ.process
  tick_count += 1

  # 125 tick ごとにドラム発音
  if tick_count % STEP_INTERVAL == 0
    note = drum_pattern[step % drum_pattern.size]
    md_uart.write((0x99).chr + note.chr + (0x60).chr)

    g = GT[note] || 4
    if g == 5
      puts "FLASH!!"
      led_strip.flash!(led_colors.size)
    else
      group_history.shift
      group_history.push(g)
      led_offset = (led_offset + 1) % led_colors.size
    end

    step += 1
  end

  sb = (saturation << 8) | brightness
  group_history.each do |g|
    h = HUES[g] << 16 | sb
    case g
    when 1
      10.times { |s|
        led_colors[(s * 6 + led_offset) % led_colors.size] = h
        led_colors[(s * 6 + 1 + led_offset) % led_colors.size] = h
        led_colors[(s * 6 + 2 + led_offset) % led_colors.size] = h
      }
    when 2
      10.times { |s|
        led_colors[(s * 6 + 3 + led_offset) % led_colors.size] = h
        led_colors[(s * 6 + 4 + led_offset) % led_colors.size] = h
        led_colors[(s * 6 + 5 + led_offset) % led_colors.size] = h
      }
    when 3
      12.times { |i| led_colors[(i * 5 + led_offset) % led_colors.size] = h }
    when 4
      6.times { |i| led_colors[(i * 10 + led_offset) % led_colors.size] = h }
    else
      puts "invalid group #{g},#{HUES[g]},#{h}"
    end
  end
  led_strip.show_hsb_hex(*led_colors)
  sleep_ms(1)
end

irq.unregister
