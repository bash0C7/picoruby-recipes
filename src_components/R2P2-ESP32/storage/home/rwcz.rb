puts "req"
require 'i2c'
require 'mpu6886'
require 'ws2812'
require 'uart'

DRUM_LED = {
  36=>0, 38=>1, 42=>2, 46=>3, 49=>4, 51=>5, 39=>6, 56=>7,
  41=>8, 43=>9, 45=>10, 47=>11, 48=>12, 50=>13, 54=>14, 52=>15
}

puts "ini"

$pc = UART.new(unit: :ESP32_UART0, baudrate: 115200)
puts "1"

$md = UART.new(unit: :ESP32_UART1, baudrate: 31250, txd_pin: 23, rxd_pin: 33)

$led = WS2812.new(RMTDriver.new(22))
$co = Array.new(60, 0)
puts "2"

$mpu = MPU6886.new(i2c_unit: :ESP32_I2C0, sda_pin: 21, scl_pin: 25, freq: 100000)
puts "3"

$bx = [0, 0, 0]
5.times do
  a = $mpu.acceleration
  $bx[0] = (a[:x] * 100).to_i
  $bx[1] = (a[:y] * 100).to_i
  $bx[2] = (a[:z] * 100).to_i
  sleep_ms(50)
end

$pc.clear_rx_buffer
sleep_ms(100)
$pc.read($pc.bytes_available) if $pc.bytes_available > 0

$md.clear_rx_buffer
sleep_ms(50)
$md.write((0xC9).chr + (25).chr)
sleep_ms(100)

$lc = 0
$cnt = 0

puts "Drum+LED"

loop do
  $lc += 1

  while $pc.bytes_available > 0
    data = $pc.read(1)
    next unless data && data.length == 1

    cmd = data[0].ord

    case cmd
    when 36..56
      puts "D:#{cmd}" if $cnt < 5
      $md.write((0x99).chr + cmd.chr + (0x7F).chr)

      pos1 = DRUM_LED[cmd] || ((cmd - 36) % 44 + 16)
      pos2 = ($lc * 7 + cmd * 3) % 60
      pos2 = (pos2 + 15) % 60 if (pos1 - pos2).abs < 5

      c = $mpu ? begin
        a = $mpu.acceleration
        dx = ((a[:x] * 100).to_i - $bx[0]).clamp(-200, 200)
        dy = ((a[:y] * 100).to_i - $bx[1]).clamp(-200, 200)
        dz = ((a[:z] * 100).to_i - $bx[2]).clamp(-200, 200)
        r = ((dx + 200) * 255 / 400).to_i
        g = ((dy + 200) * 255 / 400).to_i
        b = ((dz + 200) * 255 / 400).to_i
        (r << 16) | (g << 8) | b
      rescue
        0xFFFFFF
      end : 0xFFFFFF

      [pos1, pos2].each do |pos|
        next if pos < 0 || pos >= 60
        bri = 127
        [[pos, 255], [pos-1, 179], [pos+1, 179], [pos-2, 102], [pos+2, 102], [pos-3, 51], [pos+3, 51]].each do |p, sat_pct|
          next if p < 0 || p >= 60
          r = (c >> 16) & 0xFF
          g = (c >> 8) & 0xFF
          b_in = c & 0xFF
          sat = sat_pct / 100.0
          r = (r * sat + 255 * (1 - sat)).to_i
          g = (g * sat + 255 * (1 - sat)).to_i
          b_in = (b_in * sat + 255 * (1 - sat)).to_i
          rgb = (r << 16) | (g << 8) | b_in
          br = (rgb * bri / 255) & 0xFFFFFF
          $co[p] = $co[p] | br
        end
      end

      $cnt += 1
      puts "[#{$cnt}] #{cmd}"

    when 1..10
      lv = cmd - 1
      cc_val = (lv * 127 / 9).to_i.clamp(0, 127)
      $md.write((0xB9).chr + 91.chr + cc_val.chr)

    when 11..20
      lv = cmd - 11
      cc_val = (lv * 127 / 9).to_i.clamp(0, 127)
      $md.write((0xB9).chr + 93.chr + cc_val.chr)
    end
  end

  if $lc % 15 == 0
    60.times { |i| $co[i] = $co[i] > 5 ? $co[i] * 97 / 100 : 0 }
  end

  puts "L" if $lc % 1000 == 0

  rgb = []
  60.times do |i|
    c = $co[i]
    rgb.push((c >> 16) & 0xFF)
    rgb.push((c >> 8) & 0xFF)
    rgb.push(c & 0xFF)
  end
  $led.show_rgb(*rgb)

  sleep_ms(1)
end
