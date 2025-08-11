# Unit ASR Voice Recognition - "open" command detection
# CI-03T AI voice recognition module

# https://docs.m5stack.com/ja/unit/Unit%20ASR

require 'uart'

puts "Unit ASR Voice Recognition System Starting..."

# Grove UART initialization for Unit ASR connection
uart = UART.new(
  unit: :ESP32_UART1,
  baudrate: 115200,
  txd_pin: 26,    # Grove SDA -> UART TX
  rxd_pin: 32     # Grove SCL -> UART RX  
)

puts "UART initialized (115200bps, TX:26, RX:32)"

# Unit ASR initialization command
puts "Initializing Unit ASR..."
uart.write("\xAA\x55\xB1\x05")
sleep_ms 500

puts "Voice recognition ready"
puts "Say 'open' command"

# Main loop - voice recognition processing
loop do
  # Check UART received data
  if uart.bytes_available > 0
    data = uart.read
    
    # Convert received data to byte array
    bytes = data.bytes
    
    # Unit ASR data format check: AA 55 [command] 55 AA
    if bytes.length >= 5 && bytes[0] == 0xAA && bytes[1] == 0x55
      command_code = bytes[2]
      
      # Process existing commands
      case command_code
      when 0x30  # "ok"
        puts "Recognized: OK"
      when 0x31  # "hi, ASR"
        puts "Recognized: Hi ASR"
      when 0x32  # "hello"
        puts "Recognized: Hello"
      when 0x18  # "turn on the lights"
        puts "Recognized: Light ON"
      when 0x19  # "turn off the lights"  
        puts "Recognized: Light OFF"
      else
        # Custom command or unknown command
        puts "Received command code: 0x#{command_code.to_s(16).upcase}"
      end
      
      # "open" command detection
      # Note: Unit ASR custom command configuration required
      # Using command code 0x50 as "open" command
      if command_code == 0x50  # Custom "open" command
        puts "check, set OPEN"
      end
      
      # Debug: display received data
      hex_data = bytes.map { |b| "0x#{b.to_s(16).upcase}" }.join(" ")
      puts "Received data: #{hex_data}"
    else
      # Invalid data format
      puts "Invalid data: #{data}"
    end
  end
  
  sleep_ms 50  # Reduce CPU load
end