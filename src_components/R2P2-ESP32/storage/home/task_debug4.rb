# task_debug4.rb — reproduce ref-count GC hypothesis
# Hypothesis E: compiled bytecode (mrb) is a local var; gets GC'd when
# the wrapping method returns, killing the Task on next instruction fetch.

class Foo
  attr_accessor :running, :counter
  def initialize
    @running = true
    @counter = 0
  end
  def loop_method
    while @running
      @counter += 1
      puts "[task] counter=#{@counter}"
      sleep_ms 200
    end
    puts "[task] exit"
  end
end

# This mirrors MPU6886#start_sampling: mrb is a local; goes out of scope on return.
def start_task(foo)
  $__foo = foo
  mrb = PicoRubyVM::InstructionSequence.compile(
    '$__foo.loop_method'
  ).to_binary
  task = Task.create(mrb)
  task.run
  task
end

puts "task_debug4 starting"
foo = Foo.new
task = start_task(foo)
puts "start_task returned (mrb should now be unreferenced)"

5.times do |n|
  puts "[main #{n + 1}] counter=#{foo.counter}"
  sleep_ms 1000
end

foo.running = false
task.join
puts "main done counter=#{foo.counter}"
