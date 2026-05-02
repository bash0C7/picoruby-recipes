# task_debug5.rb — patch a diagnostic loop method onto MPU6886 itself,
# launch it via the same start_sampling-style wrapper. Isolates whether
# defining the loop method ON MPU6886 (vs a fresh class) is the trigger.

require 'mpu6886'

class MPU6886
  attr_accessor :_dbg_running, :_dbg_counter

  def _run_dbg_loop
    while @_dbg_running
      @_dbg_counter ||= 0
      @_dbg_counter += 1
      puts "[task] counter=#{@_dbg_counter}"
      sleep_ms 200
    end
    puts "[task] exit"
  end
end

def launch(mpu)
  $__mpu_dbg = mpu
  mrb = PicoRubyVM::InstructionSequence.compile(
    '$__mpu_dbg._run_dbg_loop'
  ).to_binary
  task = Task.create(mrb)
  raise "task create failed" if task.nil?
  task.run
  task
end

puts "task_debug5 starting"
i2c = I2C.new(unit: :ESP32_I2C0, frequency: 100_000, sda_pin: 25, scl_pin: 21)
mpu = MPU6886.new(i2c)
mpu._dbg_running = true
mpu._dbg_counter = 0

task = launch(mpu)
puts "launch returned"

5.times do |n|
  puts "[main #{n + 1}] counter=#{mpu._dbg_counter}"
  sleep_ms 1000
end

mpu._dbg_running = false
task.join
puts "done counter=#{mpu._dbg_counter}"
