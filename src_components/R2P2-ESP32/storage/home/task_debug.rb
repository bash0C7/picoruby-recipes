# task_debug.rb — minimal Task.create + while-loop pattern verification
# Goal: determine whether Task.create can sustain a while-loop with sleep_ms.
# If [task N] prints stop after one iteration, Task pattern itself is broken.
# If they keep printing, the bug is in _run_sampler_loop or ivar visibility.

puts "task_debug starting"

$__td_counter = 0

mrb = PicoRubyVM::InstructionSequence.compile(
  '
  i = 0
  while i < 20
    i += 1
    $__td_counter = i
    puts "[task] iter=#{i}"
    sleep_ms 200
  end
  puts "[task] loop exit"
  '
).to_binary
task = Task.create(mrb)
raise "task create failed" if task.nil?
task.run
puts "task.run returned"

5.times do |n|
  puts "[main #{n + 1}] counter=#{$__td_counter}"
  sleep_ms 1000
end

task.join
puts "main done, final counter=#{$__td_counter}"
