require 'uart'
require 'ws2812'

$pc_uart = UART.new(unit: :ESP32_UART0, baudrate: 115200)
$midi_uart = UART.new(unit: :ESP32_UART1, baudrate: 31250, txd_pin: 23, rxd_pin: 33)
$led = WS2812.new(RMTDriver.new(22))
$colors = Array.new(60, 0)
$midi_state = 0
$status_byte = 0
$note_byte = 0

# 音色設定
sleep_ms(1000)
$midi_uart.write([0xC0, 83].map(&:chr).join)
sleep_ms(100)

def update_light(note, velocity, is_note_on)
  return if note < 36 || note > 84
  
  pos = (note - 36) * 59 / 48
  return if pos < 0 || pos >= 60
  
  if is_note_on
    # Note On処理
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
    
    # 隣接位置
    $colors[pos - 1] = $colors[pos] / 3 if pos > 0
    $colors[pos + 1] = $colors[pos] / 3 if pos < 59
  else
    # Note Off処理（即座に消灯）
    $colors[pos] = 0
    $colors[pos - 1] = 0 if pos > 0
    $colors[pos + 1] = 0 if pos < 59
  end
end

def fade_lights
  i = 0
  while i < 60
    $colors[i] = $colors[i] * 97 / 100 if $colors[i] > 5
    $colors[i] = 0 if $colors[i] <= 5
    i += 1
  end
end

loop do
  data = $pc_uart.read
  
  if data && data.length > 0
    $midi_uart.write(data)
    
    data.each_byte do |byte|
      case $midi_state
      when 0  # ステータス待ち
        if byte == 0x90 || byte == 0x80
          $status_byte = byte
          $midi_state = 1
        end
      when 1  # ノート番号
        $note_byte = byte
        $midi_state = 2
      when 2  # ベロシティ
        if $status_byte == 0x90
          # Note On
          update_light($note_byte, byte, true)
        elsif $status_byte == 0x80
          # Note Off
          update_light($note_byte, 0, false)
        end
        $midi_state = 0
      end
    end
  end
  
  fade_lights
  
  # RGB出力
  rgb_array = []
  i = 0
  while i < 60
    c = $colors[i]
    rgb_array.push((c >> 16) & 0xFF)
    rgb_array.push((c >> 8) & 0xFF)
    rgb_array.push(c & 0xFF)
    i += 1
  end
  
  $led.show(rgb_array)
  sleep_ms(25)
end
