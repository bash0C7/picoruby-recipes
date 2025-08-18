# ATOM Matrix外付けLED光源ペンライト syn_pcでMIDI叩いたら色を変える

require 'uart'
require 'ws2812'

MIDI_TX = 23  # J4のG23ピン
MIDI_RX = 33  # J4のG33ピン  

puts "MIDI Through + LED + Chiff Lead + Wide Light"

pc_uart = UART.new(unit: :ESP32_UART0, baudrate: 115200)
midi_uart = UART.new(unit: :ESP32_UART1, baudrate: 31250, txd_pin: MIDI_TX, rxd_pin: MIDI_RX)

LED_PIN = 22
LED_COUNT = 60
# LED設定
led = WS2812.new(RMTDriver.new(LED_PIN))
colors = Array.new(LED_COUNT) { [0, 0, 0] }

# MIDI変数（シンプル化）
note_leds = Array.new(LED_COUNT, 0)
midi_bytes = []

# 音域定義
NOTE_MIN = 36
NOTE_MAX = 84

# 起動時にChiff Lead音色に設定
sleep_ms(1000)
program_change = [0xC0, 83].map(&:chr).join
midi_uart.write(program_change)
puts "音色設定: Chiff Lead"
sleep_ms(100)

loop do
  # MIDI受信・転送
  data = pc_uart.read
  if data && data.length > 0
    midi_uart.write(data)
    
    data.each_byte do |byte|
      midi_bytes.push(byte)
      
      # 3バイト溜まったらNote Onチェック
      if midi_bytes.length >= 3
        status = midi_bytes[-3]
        note = midi_bytes[-2]
        velocity = midi_bytes[-1]
        
        if status >= 0x90 && status <= 0x9F && velocity > 0
          if note >= NOTE_MIN && note <= NOTE_MAX
            center_pos = ((note - NOTE_MIN) * (LED_COUNT - 1)) / (NOTE_MAX - NOTE_MIN)
            
            # 色計算（オクターブベース）
            octave = (note - NOTE_MIN) / 12
            
            # 中心から前後5つずつ光らせる（直接ループ）
            start_pos = center_pos - 5
            start_pos = 0 if start_pos < 0
            end_pos = center_pos + 5
            end_pos = LED_COUNT - 1 if end_pos >= LED_COUNT
            
            i = start_pos
            while i <= end_pos
              distance = (i - center_pos).abs
              if distance <= 5
                # 明度計算（中心255 → 端51）
                brightness = 255 - (distance * 41)
                
                # 色計算（その都度）
                r = 0
                g = 0
                b = 0
                case octave % 6
                when 0  # 赤
                  r = brightness
                when 1  # 黄
                  r = brightness
                  g = brightness / 2
                when 2  # 緑
                  g = brightness
                when 3  # シアン
                  g = brightness / 2
                  b = brightness
                when 4  # 青
                  b = brightness
                when 5  # マゼンタ
                  r = brightness / 2
                  b = brightness
                end
                
                colors[i] = [r, g, b]
                note_leds[i] = brightness
              end
              i += 1
            end
            
            puts "Note: #{note}, LED: #{center_pos}, Oct: #{octave}"
          end
        end
        
        # バッファ制限
        if midi_bytes.length > 10
          midi_bytes.shift
        end
      end
    end
  end
  
  # LED更新と減衰
  i = 0
  while i < LED_COUNT
    if note_leds[i] > 0
      note_leds[i] -= 3
      note_leds[i] = 0 if note_leds[i] < 0
      
      if note_leds[i] == 0
        colors[i] = [0, 0, 0]
      end
    else
      colors[i] = [0, 0, 0]
    end
    i += 1
  end
  
  led.show_rgb(*colors)
  sleep_ms(15)
end
