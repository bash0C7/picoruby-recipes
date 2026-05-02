# task_debug9.rb — gem pattern + String allocation (no I/O)
# Hypothesis: a fresh String allocation per iteration triggers GC, which is
# the actual yield point for the Task scheduler in old mruby/c.

require 'mpu6886'

class MPU6886
  attr_accessor :_dbg9_running, :_dbg9_count

  def _run_dbg9
    while @_dbg9_running
      @_dbg9_count ||= 0
      @_dbg9_count += 1
      @_dbg9_latest = self.snapshot
      _ = "x" * 32   # cheap String allocation, no I/O
      sleep_ms(20)
    end
  end
end

def launch9(mpu)
  $__mpu_dbg9 = mpu
  mrb = PicoRubyVM::InstructionSequence.compile(
    '$__mpu_dbg9._run_dbg9'
  ).to_binary
  task = Task.create(mrb)
  raise "task9 create failed" if task.nil?
  task.run
  task
end

puts "task_debug9 starting"
i2c = I2C.new(unit: :ESP32_I2C0, frequency: 100_000, sda_pin: 25, scl_pin: 21)
mpu = MPU6886.new(i2c)
mpu.accel_range = MPU6886::ACCEL_RANGE_4G
mpu._dbg9_running = true

task = launch9(mpu)
puts "launch9 returned"

5.times do |n|
  puts "[main #{n + 1}] count=#{mpu._dbg9_count}"
  sleep_ms 1000
end

mpu._dbg9_running = false
task.join
puts "done count=#{mpu._dbg9_count}"
