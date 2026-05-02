# task_debug8.rb — gem-exact reproduction of _run_sampler_loop with puts traces
# debug6 worked (with puts, sleep_ms 200 literal); gem fails (no puts, sleep_ms ivar, 20ms).
# This patches MPU6886 with a method matching the failing gem pattern but adds
# puts so we can see exactly when the Task dies.

require 'mpu6886'

class MPU6886
  attr_accessor :_dbg_running, :_dbg_interval_ms, :_dbg_count

  def _run_dbg_gem_pattern
    while @_dbg_running
      @_dbg_count ||= 0
      @_dbg_count += 1
      puts "[task] count=#{@_dbg_count} before snapshot"
      @_dbg_latest = snapshot
      puts "[task] count=#{@_dbg_count} after snapshot, before sleep_ms(@_dbg_interval_ms=#{@_dbg_interval_ms})"
      sleep_ms(@_dbg_interval_ms)
      puts "[task] count=#{@_dbg_count} after sleep_ms"
    end
    puts "[task] loop exit"
  end
end

def launch(mpu)
  $__mpu_dbg = mpu
  mrb = PicoRubyVM::InstructionSequence.compile(
    '$__mpu_dbg._run_dbg_gem_pattern'
  ).to_binary
  task = Task.create(mrb)
  raise "task create failed" if task.nil?
  task.run
  task
end

puts "task_debug8 starting"
i2c = I2C.new(unit: :ESP32_I2C0, frequency: 100_000, sda_pin: 25, scl_pin: 21)
mpu = MPU6886.new(i2c)
mpu.accel_range = MPU6886::ACCEL_RANGE_4G
mpu._dbg_running = true
mpu._dbg_interval_ms = 20   # gem-default
mpu._dbg_count = 0

task = launch(mpu)
puts "launch returned"

5.times do |n|
  puts "[main #{n + 1}] count=#{mpu._dbg_count}"
  sleep_ms 1000
end

mpu._dbg_running = false
task.join
puts "done count=#{mpu._dbg_count}"
