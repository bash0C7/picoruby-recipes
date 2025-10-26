require 'uart'
require 'ws2812'
require 'i2c'
require 'mpu6886'

SAT=[255,179,102,51]
FADE=[-2,-1,0,1,2]
DRUM_LED=[0,nil,1,nil,nil,2,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,3,nil,nil,nil,4,5,nil,nil,nil,nil,nil,nil,6,nil,7,8,nil,9,nil,10,nil,11,12,nil,13,nil,14,nil,15]

$pc=UART.new(unit: :ESP32_UART0, baudrate: 115200)
sleep_ms(10)
$md=UART.new(unit: :ESP32_UART1, baudrate: 31250, txd_pin: 23, rxd_pin: 33)
sleep_ms(10)
$led=WS2812.new(RMTDriver.new(22))
$co=Array.new(60, 0)
sleep_ms(10)

begin
  $i2c=I2C.new(unit: :ESP32_I2C0, frequency: 100_000, sda_pin: 25, scl_pin: 21)
  sleep_ms(100)
  $u=MPU6886.new($i2c)
  sleep_ms(100)
  $u.accel_range=MPU6886::ACCEL_RANGE_2G
  sleep_ms(100)
  a=$u.acceleration
  $bl=[(a[:x]*100).to_i,(a[:y]*100).to_i,(a[:z]*100).to_i]
rescue => e
  puts "MPU6886 Error: #{e.message}"
  $bl=[0,0,0]
  $u=nil
end

$pc.clear_rx_buffer
$md.clear_rx_buffer
$md.write((0xC9).chr+(25).chr)
$tick=0

loop do
  $tick += 1

  while $pc.bytes_available > 0
    data = $pc.read(1)
    next unless data && data.length == 1
    cmd = data[0].ord

    case cmd
    when 36..56
      $md.write((0x99).chr + cmd.chr + (0x7F).chr)
      p1 = DRUM_LED[cmd-36] || ((cmd-36) % 44 + 16)
      p2 = ($tick*7 + cmd*3) % 60
      puts "D:#{cmd} p1=#{p1} p2=#{p2}"

      if $u
        a = $u.acceleration
        dx = ((a[:x]*100).to_i - $bl[0]).clamp(-200, 200)
        dy = ((a[:y]*100).to_i - $bl[1]).clamp(-200, 200)
        dz = ((a[:z]*100).to_i - $bl[2]).clamp(-200, 200)
      else
        dx = dy = dz = 0
      end

      r = ((dx + 200) * 255 / 400).to_i
      g = ((dy + 200) * 255 / 400).to_i
      b = ((dz + 200) * 255 / 400).to_i
      puts "RGB=#{r},#{g},#{b}"

      [p1,p2].each do |pos|
        next if pos<0 || pos>=60
        SAT.each_with_index do |sat, idx|
          fp = pos + FADE[idx]
          next if fp<0 || fp>=60
          rf = (r*sat) >> 8
          gf = (g*sat) >> 8
          bf = (b*sat) >> 8
          col = (rf<<16) | (gf<<8) | bf
          $co[fp] |= col
        end
      end

    when 1..10
      $md.write((0xB9).chr + 91.chr + (((cmd-1)*127/9).to_i).chr)
    when 11..20
      $md.write((0xB9).chr + 93.chr + (((cmd-11)*127/9).to_i).chr)
    end
  end

  if $tick % 100 == 0
    60.times{|i| $co[i] = $co[i] > 5 ? ($co[i] * 97 / 100) : 0}
  end

  if $tick % 500 == 0
    puts "co[0]=0x#{$co[0].to_s(16)} co[1]=0x#{$co[1].to_s(16)}"
  end

  $led.show_hex(*$co)

  sleep_ms(1)
end
