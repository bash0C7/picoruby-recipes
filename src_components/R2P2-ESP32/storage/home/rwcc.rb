require 'uart'

$pc = nil
$md = nil
$midi_buffer = []

def init_hardware
  puts "Hardware Init..."
  $pc = UART.new(unit: :ESP32_UART0, baudrate: 115200)
  sleep_ms(100)
  $pc.clear_rx_buffer
  sleep_ms(50)
  $md = UART.new(unit: :ESP32_UART1, baudrate: 31250, txd_pin: 23, rxd_pin: 33)
  sleep_ms(100)
  $md.clear_rx_buffer
  sleep_ms(50)
  init_midi_synth
  puts "Ready"
end

def init_midi_synth
  # Channel 10 (0x9) ドラムキット初期化
  $md.write((0xB9).chr + (0x00).chr + (0x00).chr)
  sleep_ms(20)
  $md.write((0xC9).chr + (0).chr)
  sleep_ms(50)
end

def process_pc_midi
  return unless $pc.bytes_available > 0
  
  # 利用可能なデータを一気に読む
  raw_data = ""
  while $pc.bytes_available > 0
    dt = $pc.read(1)
    raw_data += dt if dt && dt.length > 0
  end
  return if raw_data.length == 0
  
  # バッファに追加
  raw_data.each_byte { |b| $midi_buffer.push(b) }
  
  # 3バイトメッセージをすべて処理
  while $midi_buffer.length >= 3
    midi_msg = ""
    3.times { midi_msg += $midi_buffer.shift.chr }
    $md.write(midi_msg)  # 即座にMIDI Unitへ転送
  end
end

begin
  init_hardware
  puts "Start"
  loop_count = 0
  
  loop do
    loop_count += 1
    process_pc_midi
    
    if loop_count % 1000 == 0
      puts "L:#{loop_count}, B:#{$midi_buffer.length}"
    end
    
    sleep_ms(1)  # 高速ポーリング
  end
rescue => e
  puts "Error: #{e.message}"
end
