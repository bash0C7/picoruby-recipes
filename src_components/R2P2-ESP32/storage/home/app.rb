# app.rb — measure main-loop iteration rate of sync vs async polling
# Uses Machine.uptime_us as monotonic clock (available on latest picoruby
# ESP32 port — picoruby-machine/ports/esp32/machine.c:335).

require 'mpu6886'

DURATION_MS = 2000   # measurement window per phase
SAMPLER_HZ  = 50     # background sampler rate for async phase

i2c = I2C.new(unit: :ESP32_I2C0, frequency: 100_000, sda_pin: 25, scl_pin: 21)
mpu = MPU6886.new(i2c)
mpu.accel_range = MPU6886::ACCEL_RANGE_4G
mpu.gyro_range  = MPU6886::GYRO_RANGE_2000DPS

# --- Phase 1: sync ----------------------------------------------------
puts "Phase 1: sync acceleration() polling for ~#{DURATION_MS}ms"
sync_iters = 0
start = Machine.uptime_us / 1000
deadline = start + DURATION_MS
while (Machine.uptime_us / 1000) < deadline
  mpu.acceleration
  sync_iters += 1
end
sync_elapsed = (Machine.uptime_us / 1000) - start
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
start = Machine.uptime_us / 1000
deadline = start + DURATION_MS
while (Machine.uptime_us / 1000) < deadline
  mpu.latest_acceleration
  async_iters += 1
end
async_elapsed = (Machine.uptime_us / 1000) - start
mpu.stop_sampling

puts "  async iterations: #{async_iters} in #{async_elapsed}ms"
puts "  async rate:       #{(async_iters * 1000) / async_elapsed} Hz"

# --- Summary ----------------------------------------------------------
puts ""
puts "Summary"
puts "  sync : #{(sync_iters * 1000) / sync_elapsed} Hz (I2C-bound)"
puts "  async: #{(async_iters * 1000) / async_elapsed} Hz (cached-read; sampler at #{SAMPLER_HZ}Hz behind it)"
ratio_x10 = (async_iters * 10) / sync_iters
puts "  async/sync ratio: #{ratio_x10 / 10}.#{ratio_x10 % 10}x"
