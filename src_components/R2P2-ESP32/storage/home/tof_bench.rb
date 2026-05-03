# tof_bench.rb — comparative benchmark of three sampling strategies
#
# On femtoruby (mruby/c) Machine.uptime_us == 0, so we approximate
# wall-clock by summing sleep_ms calls + known internal sleeps:
#   read_distance: internal sleep_ms(30)
#   tick:          internal sleep_ms(33)
#   background:    33ms period, main loop sleeps explicitly
#
# Each method runs ~DURATION_MS of simulated time and reports:
#   - samples acquired (or sampler period)
#   - main-loop iterations available for other work
#
# VL53L0X connected to J3 (SDA:25, SCL:21)

require 'i2c'
require 'vl53l0x'

DURATION_MS = 3000
MAIN_LOOP_SLEEP_MS = 5

puts "VL53L0X sampling-strategy benchmark"
puts "Duration target: #{DURATION_MS}ms per method"
puts "J3: SDA=25, SCL=21"

i2c = I2C.new(
  unit: :ESP32_I2C0,
  frequency: 100_000,
  sda_pin: 25,
  scl_pin: 21,
  timeout: 2000
)

vl = VL53L0X.new(i2c)
unless vl.ready?
  puts "VL53L0X init failed"
  exit
end
puts "VL53L0X ready"
puts "==="

# --- Method 1: Blocking read_distance ---
puts "[1] Blocking read_distance (main loop fully blocked per sample)"
samples = 0
elapsed = 0
loop do
  d = vl.read_distance
  samples += 1 if d > 0
  elapsed += 30  # read_distance internal sleep_ms
  break if elapsed >= DURATION_MS
end
rate1 = (samples * 1000) / elapsed
puts "  elapsed≈#{elapsed}ms  samples=#{samples}  rate=#{rate1}/sec"
puts "  main_iterations_available=0"

# --- Method 2: Cooperative tick ---
puts "[2] Cooperative tick (sleep_ms yields, but main loop = sample loop)"
samples = 0
elapsed = 0
loop do
  samples += 1 if vl.tick
  elapsed += 33  # tick internal sleep_ms(TIMING_BUDGET_DEFAULT)
  break if elapsed >= DURATION_MS
end
rate2 = (samples * 1000) / elapsed
puts "  elapsed≈#{elapsed}ms  samples=#{samples}  rate=#{rate2}/sec"
puts "  main_iterations_available=0"

# --- Method 3: Background Task + free main loop ---
puts "[3] Background Task sampler (main loop free for other work)"
vl.start_sampling(interval_ms: 33)
sleep_ms 100  # warm up sampler

work = 0
elapsed = 0
last_d = nil
distinct = 0
loop do
  d = vl.latest_distance
  if d && d != last_d
    distinct += 1
    last_d = d
  end
  work += 1
  sleep_ms MAIN_LOOP_SLEEP_MS
  elapsed += MAIN_LOOP_SLEEP_MS
  break if elapsed >= DURATION_MS
end
vl.stop_sampling

estimated_bg_samples = elapsed / 33
rate3 = (estimated_bg_samples * 1000) / elapsed
puts "  elapsed≈#{elapsed}ms"
puts "  background_samples≈#{estimated_bg_samples}  rate≈#{rate3}/sec (33ms period)"
puts "  main_iterations_available=#{work}  (#{MAIN_LOOP_SLEEP_MS}ms each)"
puts "  distinct_distance_observations=#{distinct}"

puts "==="
puts "Summary"
puts "  Method               | samples/sec | main_iters_per_3sec"
puts "  ---------------------|-------------|--------------------"
puts "  [1] read_distance    | #{rate1.to_s.rjust(11)} | 0 (blocked)"
puts "  [2] tick             | #{rate2.to_s.rjust(11)} | 0 (loop=sample)"
puts "  [3] start_sampling   | #{rate3.to_s.rjust(11)} | #{work} (free)"
