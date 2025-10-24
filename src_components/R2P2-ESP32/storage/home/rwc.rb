require 'uart'
require 'ws2812'
require 'i2c'

$pc = nil
$md = nil
$led = nil
$mpu = nil
$co = nil
$bx = nil
$lc = 0
$cnt = 0

DRUM_LED = {
  36=>0, 38=>1, 42=>2, 46=>3, 49=>4, 51=>5, 39=>6, 56=>7,
  41=>8, 43=>9, 45=>10, 47=>11, 48=>12, 50=>13, 54=>14, 52=>15
}

DRUM_NAMES = {
  36=>"Kick", 38=>"Snare", 39=>"Clap", 41=>"LTom",
  42=>"ClHH", 43=>"LMTom", 45=>"MTom", 46=>"OpHH",
  47=>"MHTom", 48=>"HTom", 49=>"Crash", 50=>"HTom2",
  51=>"Ride", 52=>"China", 54=>"Tamb", 56=>"Cowbell"
}

def init_hardware
  puts "Init..."

  $pc = UART.new(unit: :ESP32_UART0, baudrate: 115200)
  sleep_ms(50)

  $md = UART.new(unit: :ESP32_UART1, baudrate: 31250, txd_pin: 23, rxd_pin: 33)
  sleep_ms(50)

  $led = WS2812.new(RMTDriver.new(22))
  $co = Array.new(60, 0)
  sleep_ms(50)

  begin
    $mpu = MPU6886.new(i2c_unit: :ESP32_I2C0, sda_pin: 21, scl_pin: 25, freq: 100000)
    $bx = [0, 0, 0]

    5.times do
      a = $mpu.acceleration
      $bx[0] = (a[:x] * 100).to_i
      $bx[1] = (a[:y] * 100).to_i
      $bx[2] = (a[:z] * 100).to_i
      sleep_ms(50)
    end
    puts "Accel OK"
  rescue
    puts "Accel N/A"
    $mpu = nil
  end

  $pc.clear_rx_buffer
  sleep_ms(100)

  if $pc.bytes_available > 0
    $pc.read($pc.bytes_available)
  end

  $md.clear_rx_buffer
  sleep_ms(50)

  $md.write((0xC9).chr + (25).chr)
  sleep_ms(100)

  puts "Ready!"
end

def send_midi_cc(cc, val)
  $md.write((0xB9).chr + cc.chr + val.chr)
end

def get_color
  return 0xFFFFFF unless $mpu

  begin
    a = $mpu.acceleration
    dx = (a[:x] * 100).to_i - $bx[0]
    dy = (a[:y] * 100).to_i - $bx[1]
    dz = (a[:z] * 100).to_i - $bx[2]

    dx = dx.clamp(-200, 200)
    dy = dy.clamp(-200, 200)
    dz = dz.clamp(-200, 200)

    r = ((dx + 200) * 255 / 400).to_i
    g = ((dy + 200) * 255 / 400).to_i
    b = ((dz + 200) * 255 / 400).to_i

    (r << 16) | (g << 8) | b
  rescue
    0xFFFFFF
  end
end

def light_flash(pos, vel, c)
  return if pos < 0 || pos >= 60

  bri = (vel * 2).clamp(0, 255)

  [
    [pos, 255, bri],
    [pos-1, 179, bri], [pos+1, 179, bri],
    [pos-2, 102, bri], [pos+2, 102, bri],
    [pos-3, 51, bri], [pos+3, 51, bri]
  ].each do |p, sat_pct, b|
    next if p < 0 || p >= 60

    r = (c >> 16) & 0xFF
    g = (c >> 8) & 0xFF
    b_in = c & 0xFF

    sat = sat_pct / 100.0
    r = (r * sat + 255 * (1 - sat)).to_i
    g = (g * sat + 255 * (1 - sat)).to_i
    b_in = (b_in * sat + 255 * (1 - sat)).to_i

    rgb = (r << 16) | (g << 8) | b_in
    br = (rgb * b / 255) & 0xFFFFFF

    $co[p] = $co[p] | br
  end
end

def flash_drum(note, vel)
  pos1 = DRUM_LED[note] || ((note - 36) % 44 + 16)
  pos2 = ($lc * 7 + note * 3) % 60
  pos2 = (pos2 + 15) % 60 if (pos1 - pos2).abs < 5

  c = get_color

  [pos1, pos2].each { |p| light_flash(p, vel, c) }
end

def fade_leds
  60.times do |i|
    $co[i] = $co[i] * 97 / 100 if $co[i] > 5
    $co[i] = 0 if $co[i] <= 5
  end
end

def process_commands
  return unless $pc.bytes_available > 0

  while $pc.bytes_available > 0
    data = $pc.read(1)
    next unless data && data.length == 1

    cmd = data[0].ord

    case cmd
    when 36..56
      $md.write((0x99).chr + cmd.chr + (0x7F).chr)
      flash_drum(cmd, 127)
      $cnt += 1
      name = DRUM_NAMES[cmd] || "?"
      puts "[#{$cnt}] #{cmd}:#{name}"

    when 1..10
      lv = cmd - 1
      cc_val = (lv * 127 / 9).to_i
      cc_val = 127 if cc_val > 127
      send_midi_cc(91, cc_val)

    when 11..20
      lv = cmd - 11
      cc_val = (lv * 127 / 9).to_i
      cc_val = 127 if cc_val > 127
      send_midi_cc(93, cc_val)
    end
  end
end

begin
  init_hardware

  puts "=== LED Drum Performer ==="
  puts "v2: Dual LED Flash"
  puts ""

  loop do
    $lc += 1

    process_commands

    if $lc % 15 == 0
      fade_leds
    end

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

rescue => e
  puts "E: #{e.message}"
end
