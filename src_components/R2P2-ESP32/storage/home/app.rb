require 'uart'
require 'ws2812'
require 'i2c'
require 'mpu6886'

# ===== 定数定義 =====

# MIDI
NOTE_ON = 0x99
CC = 0xB9
VEL_MAX = 0x7F
PROG_CHG = 0xC9

# LED
LED_COUNT = 60
INIT_COLOR = 0xC0960A
MAX_BRIGHT = 0x00FF

# ビット演算
HUE_SHIFT = 16
SAT_SHIFT = 8
HUE_MASK = 0xFF0000

# ===== Groupクラス定義 =====

class Group
  @@groups = {}
  @@note_map = {}
  @@rotation = []
  attr_reader :name, :hue

  def initialize(name, hue)
    @name = name
    @hue = hue
  end

  def self.create(name, hue, notes: [], rotatable: true, &block)
    g = new(name, hue)
    g.define_singleton_method(:apply_leds, block) if block
    @@groups[name] = g
    notes.each { |n| @@note_map[n] = name }
    @@rotation << g if rotatable
    g
  end

  def self.from_note(note)
    name = @@note_map[note]
    name ? @@groups[name] : @@groups[:default]
  end

  def self.[](name)
    @@groups[name]
  end

  def self.rotate(tick)
    @@rotation[tick % @@rotation.size]
  end

  def apply_leds(colors, hsb, offset)
    puts "Unknown group: name=#{@name}, hue=#{@hue}, hsb=#{hsb}, offset=#{offset}"
  end
end

# グループ定義
Group.create(:kick, 0, notes: [36]) do |colors, hsb, offset|
  10.times { |s|
    colors[(s * 6 + offset) % LED_COUNT] = hsb
    colors[(s * 6 + 1 + offset) % LED_COUNT] = hsb
    colors[(s * 6 + 2 + offset) % LED_COUNT] = hsb
  }
end

Group.create(:snare, 128, notes: [38]) do |colors, hsb, offset|
  10.times { |s|
    colors[(s * 6 + 3 + offset) % LED_COUNT] = hsb
    colors[(s * 6 + 4 + offset) % LED_COUNT] = hsb
    colors[(s * 6 + 5 + offset) % LED_COUNT] = hsb
  }
end

Group.create(:clap, 192, notes: [39]) do |colors, hsb, offset|
  12.times { |i| colors[(i * 5 + offset) % LED_COUNT] = hsb }
end

Group.create(:crash, 0, notes: [49, 52], rotatable: false)

Group.create(:default, 64) do |colors, hsb, offset|
  6.times { |i| colors[(i * 10 + offset) % LED_COUNT] = hsb }
end

ctrl = UART.new(unit: :ESP32_UART0, baudrate: 115200)
sleep_ms(10)
synth = UART.new(unit: :ESP32_UART1, baudrate: 31250, txd_pin: 23, rxd_pin: 33)
sleep_ms(10)

leds = WS2812.new(RMTDriver.new(22))
colors = Array.new(LED_COUNT, INIT_COLOR)
sleep_ms(10)

i2c_bus = I2C.new(unit: :ESP32_I2C0, frequency: 100_000, sda_pin: 25, scl_pin: 21)
sleep_ms(100)
accel = MPU6886.new(i2c_bus)
sleep_ms(100)
accel.accel_range = MPU6886::ACCEL_RANGE_2G
sleep_ms(100)

ctrl.clear_rx_buffer
synth.clear_rx_buffer
synth.write(PROG_CHG.chr + 25.chr)

button = GPIO.new(39, GPIO::IN|GPIO::PULL_UP)
last_button = 1
debounce = 0

tick = 0
hist = [Group[:kick], Group[:kick], Group[:kick]]
sat = 255
bright = 111
offset = 0

loop do
  tick += 1

  while ctrl.bytes_available > 0
    d = ctrl.read(1)
    next unless d && d.length == 1
    cmd = d[0].ord

    case cmd
    when 36..56
      synth.write(NOTE_ON.chr + cmd.chr + VEL_MAX.chr)
      hist.shift
      hist << Group.from_note(cmd)
      offset = (offset + 1) % LED_COUNT
    when 1..10
      synth.write(CC.chr + 91.chr + (((cmd - 1) * 127 / 9).to_i).chr)
    when 11..20
      synth.write(CC.chr + 93.chr + (((cmd - 11) * 127 / 9).to_i).chr)
    end
  end

  b = button.read
  if last_button == 1 && b == 0 && debounce == 0
    synth.write(NOTE_ON.chr + 49.chr + VEL_MAX.chr)
    hist[-1] = Group[:crash]
    debounce = 10
  end
  last_button = b
  debounce -= 1 if debounce > 0

  if tick % 10 == 0
    a = accel.acceleration
    mag = ((a[:x].abs + a[:y].abs + a[:z].abs) * 100).to_i
    d = mag - 100
    sat = (d * d / 20 + 127).clamp(50, 255)
    bright = ((sat - 127) * 81 / 128 + 30).clamp(15, 111)
  end

  if hist[-1] == Group[:crash]
    colors.map! { |c| (c & HUE_MASK) | MAX_BRIGHT }
    hist[-1] = Group.rotate(tick)
  else
    hsb = (sat << SAT_SHIFT) | bright
    hist.each do |g|
      h = (g.hue << HUE_SHIFT) | hsb
      g.apply_leds(colors, h, offset)
    end
  end
  leds.show_hsb_hex(*colors)
  sleep_ms(1)
end
