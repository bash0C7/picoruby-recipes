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
  $md.write((0xB9).chr + (0x00).chr + (0x00).chr)
  sleep_ms(20)
  $md.write((0xC9).chr + (0).chr)
  sleep_ms(50)
end

def process_pc_midi
  return unless $pc.bytes_available > 0
  raw_data = ""
  while $pc.bytes_available > 0
    dt = $pc.read(1)
    raw_data += dt if dt && dt.length > 0
  end
  return if raw_data.length == 0
  puts "RX:#{raw_data.length}"
  raw_data.each_byte { |b| $midi_buffer.push(b) }
  while $midi_buffer.length >= 3
    midi_msg = ""
    3.times { midi_msg += $midi_buffer.shift.chr }
    $md.write(midi_msg)
  end
end

begin
  init_hardware
  puts "Start"
  loop_count = 0
  loop do
    loop_count += 1
    process_pc_midi
    if loop_count % 500 == 0
      puts "L:#{loop_count}"
    end
    sleep_ms(20)
  end
rescue => e
  puts "Error: #{e.message}"
end
