require 'ws2812'
require 'gpio'
require 'irq'
require 'pwm'

LED_COUNT = 25
LED_PIN = 27
SPEAKER_PIN = 32

# ===== 半音対応音階定数（2オクターブ分） =====
# C4オクターブ
C4  = 0   # ド
Cs4 = 1   # ド♯
Db4 = 1   # レ♭（同じ音）
D4  = 2   # レ
Ds4 = 3   # レ♯
Eb4 = 3   # ミ♭
E4  = 4   # ミ
F4  = 5   # ファ
Fs4 = 6   # ファ♯
Gb4 = 6   # ソ♭
G4  = 7   # ソ
Gs4 = 8   # ソ♯
Ab4 = 8   # ラ♭
A4  = 9   # ラ
As4 = 10  # ラ♯
Bb4 = 10  # シ♭
B4  = 11  # シ

# C5オクターブ
C5  = 12  # ド（高）
Cs5 = 13  # ド♯
Db5 = 13  # レ♭
D5  = 14  # レ
Ds5 = 15  # レ♯
Eb5 = 15  # ミ♭
E5  = 16  # ミ
F5  = 17  # ファ
Fs5 = 18  # ファ♯
Gb5 = 18  # ソ♭
G5  = 19  # ソ
Gs5 = 20  # ソ♯
Ab5 = 20  # ラ♭
A5  = 21  # ラ
As5 = 22  # ラ♯
Bb5 = 22  # シ♭
B5  = 23  # シ

C6  = 24  # ド（最高音）

REST = 99  # 休符

# 周波数テーブル（半音刻み、C4-C6）
FREQS = [
  262, 277, 294, 311, 330, 349, 370, 392, 415, 440, 466, 494,  # C4-B4
  523, 554, 587, 622, 659, 698, 740, 784, 831, 880, 932, 988,  # C5-B5
  1047  # C6
]

# 色相テーブル（虹色グラデーション）
HUES = [
  0, 16, 32, 48, 64, 80, 96, 112, 128, 144, 160, 176,    # C4-B4
  192, 208, 224, 240, 256, 272, 288, 304, 320, 336, 352, 368,  # C5-B5
  384  # C6
]

# ===== メロディ例：ブルースペンタトニック =====
MELODY = [
  # フレーズ1: 上昇フレーズ
  D4, E4, Fs4, G4, A4, B4, A4, G4,
  Fs4, G4, A4, B4, D5, Cs5, B4, A4,
  
  # フレーズ2: 特徴的なメロディ
  D5, D5, Cs5, B4, A4, Fs4, G4, A4,
  B4, A4, G4, Fs4, E4, D4, REST, REST,
  
  # フレーズ3: 繰り返し
  D4, Fs4, A4, D5, Cs5, B4, A4, G4,
  Fs4, E4, D4, E4, Fs4, G4, A4, REST,
  
  # フレーズ4: 盛り上げ
  B4, B4, A4, G4, Fs4, G4, A4, B4,
  D5, Cs5, B4, A4, D5, REST, REST, REST
]

# 音色パターン
#DUTY_PAT = [20, 80, 30, 70, 25, 75, 35, 65]
DUTY_PAT = [40, 35, 45, 30, 50, 35, 40, 35]

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

puts "Start!"

irq = button.irq(GPIO::EDGE_FALL, debounce: 100, capture: {led_strip: led_strip}) do |btn, ev, cap|
  puts "FLASH!"
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
      
      12.times { |i| 
        led_colors[(i * 5 + led_offset) % LED_COUNT] = h 
      }
      led_offset = (led_offset + 1) % LED_COUNT
      
      puts "#{freq}Hz D#{duty}%"
    end
    
    step += 1
  end
  
  led_strip.show_hsb_hex(*led_colors)
  sleep_ms(1)
end

irq.unregister
