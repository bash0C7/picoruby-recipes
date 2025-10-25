require 'uart'
require 'ws2812'
require 'i2c'

# DRUM_LED マッピング（コンパクト版）
D = [0,nil,1,nil,nil,2,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,3,nil,nil,nil,4,5,nil,nil,nil,nil,nil,nil,6,nil,7,8,nil,9,nil,10,nil,11,12,nil,13,nil,14,nil,15]

$p = UART.new(unit: :ESP32_UART0, baudrate: 115200)
sleep_ms(10)
$m = UART.new(unit: :ESP32_UART1, baudrate: 31250, txd_pin: 23, rxd_pin: 33)
sleep_ms(10)
$l = WS2812.new(RMTDriver.new(22))
$c = Array.new(60, 0)
sleep_ms(10)
$u = MPU6886.new(i2c_unit: :ESP32_I2C0, sda_pin: 21, scl_pin: 25, freq: 100000)

a = $u.acceleration
$b = [(a[:x]*100).to_i, (a[:y]*100).to_i, (a[:z]*100).to_i]

$p.clear_rx_buffer
$m.clear_rx_buffer
sleep_ms(50)
$m.write((0xC9).chr + (25).chr)

$t = 0

loop do
  $t += 1

  while $p.bytes_available > 0
    d = $p.read(1)
    next unless d && d.length == 1
    cmd = d[0].ord

    case cmd
    when 36..56
      $m.write((0x99).chr + cmd.chr + (0x7F).chr)

      i = D[cmd-36]
      i = (cmd-36)%44+16 unless i

      j = ($t*7+cmd*3)%60
      j = (j+15)%60 if (i-j).abs < 5

      a = $u.acceleration rescue {x:0,y:0,z:0}
      dx = ((a[:x]*100).to_i - $b[0]).clamp(-200, 200)
      dy = ((a[:y]*100).to_i - $b[1]).clamp(-200, 200)
      dz = ((a[:z]*100).to_i - $b[2]).clamp(-200, 200)
      r = ((dx+200)*255/400).to_i
      g = ((dy+200)*255/400).to_i
      b = ((dz+200)*255/400).to_i
      x = (r<<16)|(g<<8)|b

      [i,j].each do |p|
        next if p<0 || p>=60
        s = [255,179,179,102,102,51,51]
        [-3,-2,-1,0,1,2,3].each_with_index do |d,x|
          q = p+d
          next if q<0 || q>=60
          rr = (r*s[x+3]+255*(255-s[x+3]))>>8
          gg = (g*s[x+3]+255*(255-s[x+3]))>>8
          bb = (b*s[x+3]+255*(255-s[x+3]))>>8
          $c[q] = $c[q] | ((rr<<16)|(gg<<8)|bb)
        end
      end

    when 1..10
      v = ((cmd-1)*127/9).to_i
      $m.write((0xB9).chr + 91.chr + v.chr)
    when 11..20
      v = ((cmd-11)*127/9).to_i
      $m.write((0xB9).chr + 93.chr + v.chr)
    end
  end

  if $t%15==0
    60.times{|i| $c[i] = $c[i]>5 ? $c[i]*97/100 : 0}
  end

  o = []
  60.times{|i| x=$c[i]; o.push((x>>16)&0xFF, (x>>8)&0xFF, x&0xFF)}
  $l.show_rgb(*o)

  sleep_ms(1)
end
