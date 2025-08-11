# https://claude.ai/chat/f6aa9f8a-3976-49ef-9998-ba6b3c6f038a
require 'uart'

UART_TX = 26
UART_RX = 32

uart = UART.new(
  unit: :ESP32_UART1,
  baudrate: 31250,
  txd_pin: UART_TX, 
  rxd_pin: UART_RX
)

# 音符定数（Arduinoヘッダーから）
NOTE_C4 = 60
NOTE_D4 = 62
NOTE_E4 = 64
NOTE_F4 = 65
NOTE_G4 = 67
NOTE_A4 = 69
NOTE_B4 = 71
NOTE_C5 = 72

# 楽器定数
GrandPiano_1 = 0

def busy_wait_ms(duration_ms)
  sleep_ms(duration_ms)
end

# 実績のある.chr形式
def set_instrument(uart, bank, channel, program)
  # Bank Select Control Change
  status = (0xB0 + channel).chr
  cc_byte = 0x00.chr
  bank_byte = bank.chr
  data1 = status + cc_byte + bank_byte
  uart.write(data1)
  busy_wait_ms(10)
  
  # Program Change
  status = (0xC0 + channel).chr
  prog_byte = program.chr
  data2 = status + prog_byte
  uart.write(data2)
  busy_wait_ms(50)
  puts "Instrument: Bank=#{bank}, Channel=#{channel}, Program=#{program}"
end

def set_note_on(uart, channel, pitch, velocity)
  status = (0x90 + channel).chr
  pitch_byte = pitch.chr
  vel_byte = velocity.chr
  data = status + pitch_byte + vel_byte
  uart.write(data)
  puts "Note On: #{pitch}"
end

def play_three_notes(uart, ch1, ch2, ch3, note1, note2, note3, velocity, duration)
  # 3チャンネル同時発音
  [[ch1, note1], [ch2, note2], [ch3, note3]].each do |ch, note|
    if note > 0  # 0は休符
      data = (0x90 + ch).chr + note.chr + velocity.chr
      uart.write(data)
      busy_wait_ms(5)
    end
  end
  busy_wait_ms(duration)
end

puts "Unit Synth Piano (PicoRuby版・実績形式)"
busy_wait_ms(2000)

# 3つのチャンネルに楽器設定
set_instrument(uart, 0, 0, 0)   # Ch0: Piano
set_instrument(uart, 0, 1, 57)  # Ch1: Trumpet  
set_instrument(uart, 0, 2, 41)  # Ch2: Violin

# メロディー配列（ここに好きな楽曲を入力）
# [ch0_note, ch1_note, ch2_note, duration_ms]
melody = [
  [60, 64, 67, 500],  # C-E-G 和音
  [62, 65, 69, 500],  # D-F-A 和音
  [64, 67, 71, 500],  # E-G-B 和音
  [65, 69, 72, 500],  # F-A-C 和音
  [67, 71, 74, 1000], # G-B-D 和音（長め）
]

puts "演奏開始"
melody.each do |note1, note2, note3, duration|
  play_three_notes(uart, 0, 1, 2, note1, note2, note3, 127, duration)
end

puts "演奏完了"
