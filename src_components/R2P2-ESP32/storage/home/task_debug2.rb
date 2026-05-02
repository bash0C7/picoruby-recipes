# task_debug2.rb — isolate "while @ivar" pattern from MPU6886
# Mirrors _run_sampler_loop structure without I2C, to determine whether
# `while @ivar` re-reads the ivar each iteration in mruby/c Task context.

class Foo
  attr_accessor :running, :counter
  def initialize
    @running = true
    @counter = 0
  end

  def loop_method
    while @running
      @counter += 1
      puts "[task] counter=#{@counter} running=#{@running}"
      sleep_ms 200
    end
    puts "[task] loop exit (running=#{@running})"
  end
end

puts "task_debug2 starting"

foo = Foo.new
$__foo = foo

mrb = PicoRubyVM::InstructionSequence.compile(
  '$__foo.loop_method'
).to_binary
task = Task.create(mrb)
raise "task create failed" if task.nil?
task.run
puts "task.run returned"

5.times do |n|
  puts "[main #{n + 1}] counter=#{foo.counter} running=#{foo.running}"
  sleep_ms 1000
end

foo.running = false
puts "[main] set running=false, joining..."
task.join
puts "main done counter=#{foo.counter}"
