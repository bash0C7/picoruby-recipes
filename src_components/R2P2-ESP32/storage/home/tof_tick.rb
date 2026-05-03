# tof_tick.rb — cooperative tick sampler verification
# Each tick call: start_measurement -> sleep_ms(33) -> get_distance.
# Mirrors _run_sampler_loop pattern (proven working). One call per sample.
# VL53L0X connected to J3 (SDA:25, SCL:21)

require 'i2c'
require 'vl53l0x'

puts "VL53L0X tick sampler test"
puts "J3: SDA=25, SCL=21"

i2c = I2C.new(
  unit: :ESP32_I2C0,
  frequency: 100_000,
  sda_pin: 25,
  scl_pin: 21,
  timeout: 2000
)

vl53l0x = VL53L0X.new(i2c)

unless vl53l0x.ready?
  puts "Failed to initialize VL53L0X"
  exit
end

puts "VL53L0X initialized"
puts "Starting tick loop (1 call = 1 sample, ~33ms cooperative wait per call)..."
puts "---"

samples = 0

loop do
  if vl53l0x.tick
    samples += 1
    dist = vl53l0x.latest_distance
    if dist && dist > 0
      puts "[sample #{samples}] Distance: #{dist}mm"
    else
      puts "[sample #{samples}] Out of range or error (#{dist.inspect})"
    end
  end

  break if samples >= 20
end

puts "---"
puts "Done. samples=#{samples}"
