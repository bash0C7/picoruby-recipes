require 'uart'

serial = UART.open('/dev/cu.usbserial-5D5A501DF0', 115200)
str = (ARGV.first || "b").downcase
puts str
serial.write str
