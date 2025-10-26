require 'uart'
require 'ws2812'
require 'i2c'
require 'mpu6886'

GT = {36=>1, 38=>2, 39=>3, 49=>5, 52=>5}

pc_uart = UART.new(unit: :ESP32_UART0, baudrate: 115200)
sleep_ms(10)
md_uart = UART.new(unit: :ESP32_UART1, baudrate: 31250, txd_pin: 23, rxd_pin: 33)
sleep_ms(10)

led_strip = WS2812.new(RMTDriver.new(22))
led_colors = Array.new(60, 0x00000A)
sleep_ms(10)

begin
  i2c_bus = I2C.new(unit: :ESP32_I2C0, frequency: 100_000, sda_pin: 25, scl_pin: 21)
  sleep_ms(100)
  accel_sensor = MPU6886.new(i2c_bus)
  sleep_ms(100)
  accel_sensor.accel_range = MPU6886::ACCEL_RANGE_2G
  sleep_ms(100)
rescue => e
  puts "MPU6886 Error: #{e.message}"
  accel_sensor = nil
end

pc_uart.clear_rx_buffer
md_uart.clear_rx_buffer
md_uart.write((0xC9).chr + (25).chr)

tick_count = 0
pad_history = Array.new(5, 36)
history_idx = 0
saturation = 128
brightness = 128
hue_shift = 0
last_pad = 0
prev_ax = 0
prev_ay = 0
prev_az = 0

loop do
  tick_count += 1

  while pc_uart.bytes_available > 0
    uart_data = pc_uart.read(1)
    next unless uart_data && uart_data.length == 1
    cmd_byte = uart_data[0].ord

    case cmd_byte
    when 36..56
      md_uart.write((0x99).chr + cmd_byte.chr + (0x7F).chr)
      last_pad = cmd_byte
      unless cmd_byte == 49 || cmd_byte == 52
        pad_history[history_idx] = cmd_byte
        history_idx = (history_idx + 1) % 5
      end

    when 1..10
      md_uart.write((0xB9).chr + 91.chr + (((cmd_byte - 1) * 127 / 9).to_i).chr)
    when 11..20
      md_uart.write((0xB9).chr + 93.chr + (((cmd_byte - 11) * 127 / 9).to_i).chr)
    end
  end

  if tick_count % 15 == 0 && accel_sensor
    accel_data = accel_sensor.acceleration
    curr_ax = (accel_data[:x] * 100).to_i
    curr_ay = (accel_data[:y] * 100).to_i
    curr_az = (accel_data[:z] * 100).to_i

    hue_shift = (curr_az.clamp(-100, 100) * 30 / 100).to_i

    speed_z = (curr_az - prev_az).abs.clamp(0, 150)
    saturation = (speed_z * 255 / 150).to_i

    speed_xy = ((curr_ax - prev_ax).abs + (curr_ay - prev_ay).abs).clamp(0, 200)
    brightness = (speed_xy * 255 / 200).to_i

    prev_ax = curr_ax
    prev_ay = curr_ay
    prev_az = curr_az
  end

  60.times { |i| led_colors[i] = 0x00000A }

  g = 0
  5.times { |i| n = pad_history[i]; g |= 1 << ((GT[n] || 4) - 1) }

  sb = (saturation << 8) | brightness

  10.times { |s| 3.times { |o| led_colors[s * 6 + o] = (hue_shift << 16) | sb } } if (g & 1) != 0
  10.times { |s| 3.times { |o| led_colors[s * 6 + 3 + o] = ((170 + hue_shift) << 16) | sb } } if (g & 2) != 0
  12.times { |i| led_colors[i * 5] = ((191 + hue_shift) << 16) | sb } if (g & 4) != 0
  6.times { |i| led_colors[i * 10] = ((42 + hue_shift) << 16) | sb } if (g & 8) != 0

  60.times { |i| led_colors[i] = 0x0000FF } if last_pad == 49 || last_pad == 52

  led_strip.show_hsb_hex(*led_colors)
  sleep_ms(1)
end
