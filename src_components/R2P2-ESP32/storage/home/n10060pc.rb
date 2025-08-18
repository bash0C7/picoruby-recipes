require 'uart'
require 'ws2812'

puts "1. ライブラリ読み込み完了"

$pc_uart = UART.new(unit: :ESP32_UART0, baudrate: 115200)
puts "2. PC_UART初期化完了"

$midi_uart = UART.new(unit: :ESP32_UART1, baudrate: 31250, txd_pin: 23, rxd_pin: 33)
puts "3. MIDI_UART初期化完了"

$led = WS2812.new(RMTDriver.new(22))
puts "4. LED初期化完了"

$colors = Array.new(60, 0)
puts "5. カラー配列初期化完了"

$midi_state = 0
$status_byte = 0
$note_byte = 0
puts "6. グローバル変数初期化完了"

# 音色設定
sleep_ms(1000)
puts "7. スリープ完了"

# 手動で安全にバイト変換
puts "8-1. 手動バイト変換開始"
byte1 = 0xC0.chr
puts "8-2. 1バイト目変換完了"
byte2 = 83.chr  
puts "8-3. 2バイト目変換完了"
program_change = byte1 + byte2
puts "8-4. データ結合完了"
$midi_uart.write(program_change)
puts "8-5. MIDI音色設定送信完了"

sleep_ms(100)
puts "9. 音色設定後スリープ完了"

def update_light(note, velocity, is_note_on)
  return if note < 36 || note > 84
  
  pos = (note - 36) * 59 / 48
  return if pos < 0 || pos >= 60
  
  if is_note_on
    color_type = ((note - 36) / 12) % 6
    brightness = velocity * 2
    brightness = 255 if brightness > 255
    
    case color_type
    when 0; $colors[pos] = brightness << 16
    when 1; $colors[pos] = brightness << 8
    when 2; $colors[pos] = brightness
    when 3; $colors[pos] = (brightness << 16) | (brightness << 8)
    when 4; $colors[pos] = (brightness << 8) | brightness
    when 5; $colors[pos] = (brightness << 16) | brightness
    end
    
    $colors[pos - 1] = $colors[pos] / 3 if pos > 0
    $colors[pos + 1] = $colors[pos] / 3 if pos < 59
  else
    $colors[pos] = 0
    $colors[pos - 1] = 0 if pos > 0
    $colors[pos + 1] = 0 if pos < 59
  end
end

puts "10. update_light関数定義完了"

def fade_lights
  i = 0
  while i < 60
    $colors[i] = $colors[i] * 97 / 100 if $colors[i] > 5
    $colors[i] = 0 if $colors[i] <= 5
    i += 1
  end
end

puts "11. fade_lights関数定義完了"

def build_rgb_array
  rgb_array = []
  i = 0
  while i < 60
    c = $colors[i]
    r = (c >> 16) & 0xFF
    g = (c >> 8) & 0xFF
    b = c & 0xFF
    rgb_array.push(r)
    rgb_array.push(g)
    rgb_array.push(b)
    i += 1
  end
  rgb_array
end

puts "12. build_rgb_array関数定義完了"

puts "13. メインループ開始"
loop_count = 0

loop do
  loop_count += 1
  if loop_count % 100 == 0
    puts "ループ#{loop_count}回目実行中"
  end
  
  puts "14. データ読み取り開始" if loop_count == 1
  data = $pc_uart.read
  puts "15. データ読み取り完了" if loop_count == 1
  
  if data && data.length > 0
    puts "16. データあり: 長さ#{data.length}" if loop_count <= 3
    
    puts "17. MIDI転送開始" if loop_count <= 3
    $midi_uart.write(data)
    puts "18. MIDI転送完了" if loop_count <= 3
    
    puts "19. バイト処理開始" if loop_count <= 3
    byte_index = 0
    while byte_index < data.length
      puts "20. バイト#{byte_index}処理中" if loop_count == 1
      
      byte = data[byte_index].ord
      puts "21. ord処理完了: #{byte}" if loop_count == 1
      
      case $midi_state
      when 0
        if byte == 0x90 || byte == 0x80
          $status_byte = byte
          $midi_state = 1
        end
      when 1
        $note_byte = byte
        $midi_state = 2
      when 2
        if $status_byte == 0x90
          update_light($note_byte, byte, true)
        elsif $status_byte == 0x80
          update_light($note_byte, 0, false)
        end
        $midi_state = 0
      end
      
      byte_index += 1
    end
    puts "22. バイト処理完了" if loop_count <= 3
  end
  
  puts "23. フェード処理開始" if loop_count == 1
  fade_lights
  puts "24. フェード処理完了" if loop_count == 1
  
  puts "25. LED表示開始" if loop_count == 1
  $led.show_hex(*$colors)
  puts "26. LED表示完了" if loop_count == 1
  
  puts "27. スリープ開始" if loop_count == 1
  sleep_ms(25)
  puts "28. スリープ完了" if loop_count == 1
end