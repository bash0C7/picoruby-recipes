require 'uart'
require 'ws2812'
require 'i2c'
require 'mpu6886'

BR=[0x66,0xB3,0xFF,0xB3,0x66]

pc_uart=UART.new(unit: :ESP32_UART0, baudrate: 115200)
sleep_ms(10)
md_uart=UART.new(unit: :ESP32_UART1, baudrate: 31250, txd_pin: 23, rxd_pin: 33)
sleep_ms(10)

led_strip=WS2812.new(RMTDriver.new(22))
led_colors=Array.new(60, 0x030303)
sleep_ms(10)

begin
  i2c_bus=I2C.new(unit: :ESP32_I2C0, frequency: 100_000, sda_pin: 25, scl_pin: 21)
  sleep_ms(100)
  accel_sensor=MPU6886.new(i2c_bus)
  sleep_ms(100)
  accel_sensor.accel_range=MPU6886::ACCEL_RANGE_2G
  sleep_ms(100)
rescue => e
  puts "MPU6886 Error: #{e.message}"
  accel_sensor=nil
end

pc_uart.clear_rx_buffer
md_uart.clear_rx_buffer
md_uart.write((0xC9).chr+(25).chr)

tick_count=0
pad_history=Array.new(5, 49)
history_idx=0
prev_ax=0
prev_ay=0
prev_az=0
color_red=0
color_blue=0

loop do
  tick_count += 1

  while pc_uart.bytes_available > 0
    uart_data = pc_uart.read(1)
    next unless uart_data && uart_data.length == 1
    cmd_byte = uart_data[0].ord

    case cmd_byte
    when 36..56
      md_uart.write((0x99).chr + cmd_byte.chr + (0x7F).chr)
      pad_history[history_idx] = cmd_byte
      history_idx = (history_idx + 1) % 5

    when 1..10
      md_uart.write((0xB9).chr + 91.chr + (((cmd_byte-1)*127/9).to_i).chr)
    when 11..20
      md_uart.write((0xB9).chr + 93.chr + (((cmd_byte-11)*127/9).to_i).chr)
    end
  end

  if tick_count % 15 == 0 && accel_sensor
    accel_data = accel_sensor.acceleration
    curr_ax = (accel_data[:x] * 100).to_i
    curr_ay = (accel_data[:y] * 100).to_i
    curr_az = (accel_data[:z] * 100).to_i

    speed_val = (curr_ax-prev_ax).abs + (curr_ay-prev_ay).abs + (curr_az-prev_az).abs
    color_red = (speed_val.clamp(0,300) * 255 / 300).to_i
    color_blue = (curr_az.abs.clamp(0,200) * 255 / 200).to_i

    prev_ax = curr_ax
    prev_ay = curr_ay
    prev_az = curr_az
  end

  60.times {|idx| led_colors[idx] = 0x030303}

  5.times do |hist_pos|
    pad_note = pad_history[hist_pos]
    seed_val = pad_note * 7 + hist_pos * 11
    num_positions = 3 + (pad_note % 3)

    num_positions.times do |pos_idx|
      cp = (seed_val + pos_idx * 13 + pos_idx * pos_idx * 5) % 60

      5.times do |i|
        p = (cp + i + 58) % 60
        tr = (color_red * BR[i]) >> 8
        tg = (0xFF * BR[i]) >> 8
        tb = (color_blue * BR[i]) >> 8
        o = led_colors[p]
        r = (o>>16) & 0xFF
        g = (o>>8) & 0xFF
        b = o & 0xFF
        led_colors[p] = ((tr>r ? tr:r)<<16) | ((tg>g ? tg:g)<<8) | (tb>b ? tb:b)
      end
    end
  end

  led_strip.show_hex(*led_colors)
  sleep_ms(1)
end
