# PicoRuby Absolute Minimal Test
# Test basic functionality first

# Try with just one require at a time
require 'uart'

#u1 = UART.new(unit: :ESP32_UART1, txd_pin: 32, rxd_pin: 33, baudrate: 38400) #grove
#u1.puts "@MD2"
#u1.puts "@ACabcdefghijklmn"

# Basic UART only - no RMT yet
uart = UART.new(unit: :ESP32_UART0, baudrate: 115200)

uart.puts "Start"

# Minimal loop
loop do
  input = uart.read
  puts input
  if input == "red"
    uart.puts "RED"
  elsif input == "green"
    uart.puts "GREEN"
  elsif input == "blue"
    uart.puts "BLUE"
  elsif input == "quit"
    uart.puts "QUIT"
    break
  end
  sleep_ms 50
end

uart.puts "End"
