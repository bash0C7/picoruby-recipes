require 'uart'

serial = UART.open(Dir.glob('/dev/cu.usbserial*').first, 115200)
str = (ARGV.first || "b").downcase
serial.write str
