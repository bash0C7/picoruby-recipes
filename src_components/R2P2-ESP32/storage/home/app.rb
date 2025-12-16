require 'ws2812'
require 'gpio'
require 'irq'
require 'pwm'

LED_COUNT = 25
LED_PIN = 27
SPEAKER_PIN = 32

C4=0; Cs4=1; Db4=1; D4=2; Ds4=3; Eb4=3; E4=4; F4=5; Fs4=6; Gb4=6
G4=7; Gs4=8; Ab4=8; A4=9; As4=10; Bb4=10; B4=11
C5=12; Cs5=13; Db5=13; D5=14; Ds5=15; Eb5=15; E5=16; F5=17; Fs5=18; Gb5=18
G5=19; Gs5=20; Ab5=20; A5=21; As5=22; Bb5=22; B5=23
C6=24; REST=99

FREQS = [262,277,294,311,330,349,370,392,415,440,466,494,523,554,587,622,659,698,740,784,831,880,932,988,1047]
HUES = [0,16,32,48,64,80,96,112,128,144,160,176,192,208,224,240,256,272,288,304,320,336,352,368,384]

MELODY = [
  D4,E4,Fs4,G4,A4,B4,A4,G4,Fs4,G4,A4,B4,D5,Cs5,B4,A4,
  D5,D5,Cs5,B4,A4,Fs4,G4,A4,B4,A4,G4,Fs4,E4,D4,REST,REST,
  D4,Fs4,A4,D5,Cs5,B4,A4,G4,Fs4,E4,D4,E4,Fs4,G4,A4,REST,
  B4,B4,A4,G4,Fs4,G4,A4,B4,D5,Cs5,B4,A4,D5,REST,REST,REST
]

DUTY_PAT = [40,35,45,30,50,35,40,35]
STEP_INTERVAL = 7

speaker = PWM.new(SPEAKER_PIN, frequency: 440, duty: 0)
button = GPIO.new(39, GPIO::IN|GPIO::PULL_UP)
led_strip = WS2812.new(RMTDriver.new(LED_PIN))
led_colors = Array.new(LED_COUNT, 0)

tick_count = 0
step = 0
led_offset = 0
saturation = 180
brightness = 60

irq = button.irq(GPIO::EDGE_FALL, debounce: 100, capture: {led_strip: led_strip}) do |btn, ev, cap|
  cap[:led_strip].flash!(LED_COUNT)
end

loop do
  IRQ.process
  tick_count += 1
  if tick_count % STEP_INTERVAL == 0
    note_idx = MELODY[step % MELODY.size]
    if note_idx == REST
      speaker.duty(0)
    else
      freq = FREQS[note_idx]
      duty = DUTY_PAT[step % DUTY_PAT.size]
      speaker.frequency(freq)
      speaker.duty(duty)
      hue = HUES[note_idx % HUES.size]
      h = hue << 16 | (saturation << 8) | brightness
      12.times { |i| led_colors[(i * 5 + led_offset) % LED_COUNT] = h }
      led_offset = (led_offset + 1) % LED_COUNT
    end
    step += 1
  end
  led_strip.show_hsb_hex(*led_colors)
  sleep_ms(1)
end

irq.unregister
