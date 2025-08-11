require 'uart'
require 'ws2812'

# Grove GPIO configuration 
UART_TX = 26  # PortD G19 for MIDI TX
UART_RX = 32  # PortD G22 for MIDI RX

puts "MIDI Through + LED"

# UART設定
pc_uart = UART.new(unit: :ESP32_UART0, baudrate: 115200)
unit_uart = UART.new(unit: :ESP32_UART1, baudrate: 31250, txd_pin: UART_TX, rxd_pin: UART_RX)

# LED設定
led = WS2812.new(RMTDriver.new(27))
colors = Array.new(25) { [0, 0, 0] }

# MIDI変数
note_leds = Array.new(25, 0)
midi_bytes = []

loop do
  # MIDI受信・転送
  data = pc_uart.read
  if data && data.length > 0
    unit_uart.write(data)
    
    data.each_byte do |byte|
      midi_bytes.push(byte)
      
      # 3バイト溜まったらNote Onチェック
      if midi_bytes.length >= 3
        status = midi_bytes[-3]
        note = midi_bytes[-2]
        velocity = midi_bytes[-1]
        
        if status >= 0x90 && status <= 0x9F && velocity > 0
          # 光る場所：ノート番号を25で割った余り
          led_pos = note % 25
          
          # 輝度：ベロシティ * 2（最大255）
          brightness = velocity * 2
          brightness = brightness > 255 ? 255 : brightness
          
          # 色：オクターブ（ノート/12）で決定
          octave = note / 12
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
          
          # メインLED
          colors[led_pos] = [r, g, b]
          note_leds[led_pos] = brightness
          
          # 周囲LEDに弱い光（簡単版）
          weak = brightness / 4
          weak_r = r / 4
          weak_g = g / 4
          weak_b = b / 4
          
          # 隣接4方向
          neighbors = []
          neighbors.push(led_pos - 5) if led_pos >= 5      # 上
          neighbors.push(led_pos + 5) if led_pos < 20      # 下
          neighbors.push(led_pos - 1) if led_pos % 5 != 0  # 左
          neighbors.push(led_pos + 1) if led_pos % 5 != 4  # 右
          
          neighbors.each do |pos|
            colors[pos] = [weak_r, weak_g, weak_b]
            note_leds[pos] = weak
          end
          
          puts "Note: #{note}, LED: #{led_pos}, Oct: #{octave}, Vel: #{velocity}"
        end
        
        # バッファ制限
        if midi_bytes.length > 10
          midi_bytes.shift
        end
      end
    end
  end
  
  # LED更新と減衰
  25.times do |i|
    if note_leds[i] > 0
      # 減衰処理
      note_leds[i] -= 5
      note_leds[i] = 0 if note_leds[i] < 0
    else
      colors[i] = [0, 0, 0]
    end
  end
  
  led.show_rgb(*colors)
  sleep_ms(10)
end
