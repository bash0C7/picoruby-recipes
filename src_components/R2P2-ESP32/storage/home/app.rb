# app.rb — measure main-loop iteration rate of sync vs async polling
# This picoruby has neither Machine.uptime_us nor a working get_hwclock,
# so we build a poor-man's monotonic clock via a background Task that
# bumps $_clock_ms once per ms.

require 'mpu6886'

DURATION_MS = 2000   # measurement window per phase
SAMPLER_HZ  = 50     # background sampler rate for async phase

# --- Task-driven clock ------------------------------------------------
$_clock_ms = 0
$__clock_running = true
$__clock_self = self  # keep a global ref to anchor the bytecode

clock_mrb = PicoRubyVM::InstructionSequence.compile(
  '
  while $__clock_running
    $_clock_ms += 1
    Task.pass
    sleep_ms 1
  end
  '
).to_binary
clock_task = Task.create(clock_mrb)
raise "clock task create failed" if clock_task.nil?
clock_task.run

# Let the clock spin up briefly.
sleep_ms 50

# --- Sensor setup -----------------------------------------------------
i2c = I2C.new(unit: :ESP32_I2C0, frequency: 100_000, sda_pin: 25, scl_pin: 21)
mpu = MPU6886.new(i2c)
mpu.accel_range = MPU6886::ACCEL_RANGE_4G
mpu.gyro_range  = MPU6886::GYRO_RANGE_2000DPS

# --- Phase 1: sync ----------------------------------------------------
puts "Phase 1: sync acceleration() polling for ~#{DURATION_MS}ms"
sync_iters = 0
last_sample = nil
start = $_clock_ms
deadline = start + DURATION_MS
while $_clock_ms < deadline
  last_sample = mpu.acceleration
  sync_iters += 1
end
sync_elapsed = $_clock_ms - start
puts "  sync iterations: #{sync_iters} in #{sync_elapsed}ms"
puts "  sync rate:       #{(sync_iters * 1000) / sync_elapsed} Hz"

# --- Phase 2: async ---------------------------------------------------
sleep_ms 200
puts ""
puts "Phase 2: async latest_acceleration() polling for ~#{DURATION_MS}ms"
puts "  background sampler at #{SAMPLER_HZ}Hz (#{1000 / SAMPLER_HZ}ms interval)"
mpu.start_sampling(interval_ms: 1000 / SAMPLER_HZ)
sleep_ms 50

async_iters = 0
last_sample = nil
start = $_clock_ms
deadline = start + DURATION_MS
while $_clock_ms < deadline
  last_sample = mpu.latest_acceleration
  async_iters += 1
end
async_elapsed = $_clock_ms - start
mpu.stop_sampling

puts "  async iterations: #{async_iters} in #{async_elapsed}ms"
puts "  async rate:       #{(async_iters * 1000) / async_elapsed} Hz"

# --- Summary ----------------------------------------------------------
$__clock_running = false
clock_task.join

puts ""
puts "Summary"
puts "  sync : #{(sync_iters * 1000) / sync_elapsed} Hz (I2C-bound)"
puts "  async: #{(async_iters * 1000) / async_elapsed} Hz (cached-read; sampler at #{SAMPLER_HZ}Hz behind it)"
ratio_x10 = (async_iters * 10) / sync_iters
puts "  async/sync ratio: #{ratio_x10 / 10}.#{ratio_x10 % 10}x"
