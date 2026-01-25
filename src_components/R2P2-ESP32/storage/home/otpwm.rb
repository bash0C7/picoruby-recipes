DEBUG = true  # デバッグモード。true=小音量+デバッグ出力、false=通常音量
MUTE = false   # PWM消音モード。true=音を出さずログ出力のみ、false=実際に音を出す

class DPWM
  def initialize(pin, param = {})
    puts "new #{pin}, #{param.to_s}"
    @mute = param[:mute]
  end

  def frequency(f)
    puts "frequency #{f}" if @mute
  end

  def duty(d)
    puts "duty #{d}" if @mute
  end
end

require 'ws2812'
require 'gpio'
require 'irq'
require 'pwm'
require 'i2c'
require 'mpu6886'
require 'vl53l0x'
require 'iir_filter'
require 'uart'

class OtamatoneController
  SPEAKER_PIN = 33      # スピーカーのGPIOピン番号
  I2C_SDA_PIN = 25      # I2C SDAピン(センサー接続用)
  I2C_SCL_PIN = 21      # I2C SCLピン(センサー接続用)
  
  DIST_MIN = 20         # 演奏可能な最小距離(mm)。小さくすると近距離でも演奏可、大きくすると遠距離から演奏開始
  DIST_MAX = 280        # 演奏可能な最大距離(mm)。大きくすると演奏範囲が広がる、小さくすると狭い範囲で演奏
  
  OCTAVE_RANGE = 1.5    # 音域(オクターブ)。大きくすると音域広く・狙いにくい、小さくすると音域狭く・狙いやすい(1.0=1オクターブ、1.5=1.5オクターブ、2.0=2オクターブ)
  NOTE_RANGE = (OCTAVE_RANGE * 12).to_i  # 半音の数(自動計算)
  FREQ_MIN = 262        # 最低周波数(Hz)。C4=ド。大きくすると音域全体が高くなる
  FREQ_MAX = (FREQ_MIN * (2 ** OCTAVE_RANGE)).to_i  # 最高周波数(Hz、自動計算)
  
  BASE_DUTY = DEBUG ? 15 : 35           # 基準duty比(%)。大きくすると音量大、小さくすると音量小
  DUTY_MIN = DEBUG ? 10 : 20            # 最小duty比(%)。加速度センサーによる音量変化の下限
  DUTY_MAX = DEBUG ? 25 : 50            # 最大duty比(%)。加速度センサーによる音量変化の上限
  DUTY_DELTA_SCALE = DEBUG ? 7 : 15     # 加速度→duty変化の感度。大きくすると傾きで音量変化が激しい、小さくすると緩やか
  
  VIBRATO_SCALE = 20                    # ビブラートの強さ(Hz)。大きくすると揺れが激しい、小さくすると揺れが緩やか
  DUTY_SMOOTH_FACTOR = 4                # duty変化の滑らかさ。大きくするとゆっくり変化(滑らか)、小さくすると速く変化(応答性高)
  DUTY_SILENT_THRESHOLD = 5             # 消音判定の閾値。この値以下でLED演出をドラムモードに切替
  
  attr_reader :current_freq, :current_duty, :note_idx, :is_playing
  
  def initialize(speaker, tof_sensor, accel_sensor)
    @speaker = speaker
    @tof_sensor = tof_sensor
    @accel_sensor = accel_sensor
    @distance_filter = IIRFilter.new
    
    @base_duty = BASE_DUTY
    @duty_min = DUTY_MIN
    @duty_max = DUTY_MAX
    @duty_delta_scale = DUTY_DELTA_SCALE
    
    @current_freq = FREQ_MIN
    @current_duty = 1
    @target_duty = 1
    @is_playing = false
    @note_idx = 0
    @led_offset = 0
    
    @freq_range = FREQ_MAX - FREQ_MIN
    @dist_range = DIST_MAX - DIST_MIN
  end
  
  def update_distance
    distance = @distance_filter.filter(@tof_sensor.read_distance)
    
    if distance > 0 && distance >= DIST_MIN && distance <= DIST_MAX
      base_freq = FREQ_MIN + (DIST_MAX - distance) * @freq_range / @dist_range
      @current_freq = base_freq.clamp(FREQ_MIN, FREQ_MAX)
      @target_duty = @base_duty
      @is_playing = true
      
      @note_idx = ((DIST_MAX - distance) * NOTE_RANGE / @dist_range).to_i.clamp(0, NOTE_RANGE - 1)
      @led_offset = (@led_offset + 1) % LEDVisualizer::LED_COUNT
    else
      @target_duty = 1
      @is_playing = false
    end
    
    @speaker.frequency(@current_freq)
    
    puts "D #{distance}, T #{@target_duty}, C #{@current_duty}, P #{@is_playing}" if DEBUG
  end
  
  def update_accel
    accel_data = @accel_sensor.acceleration
    
    vibrato = (accel_data[:y] * VIBRATO_SCALE).to_i
    @speaker.frequency((@current_freq + vibrato).clamp(FREQ_MIN, FREQ_MAX))
    
    duty_delta = (accel_data[:x] * @duty_delta_scale).to_i
    target_with_accel = (@target_duty + duty_delta).clamp(@duty_min, @duty_max)
    
    if @target_duty == 1
      target_with_accel = 1
    end
    
    @current_duty += (target_with_accel - @current_duty) / DUTY_SMOOTH_FACTOR
    @current_duty = @current_duty.clamp(1, @duty_max)
    
    @speaker.duty(@current_duty)
    
    return accel_data
  end
  
  def led_offset
    @led_offset
  end
end

class DrumSequencer
  MIDI_TX_PIN = 26      # MIDI送信ピン
  MIDI_RX_PIN = 32      # MIDI受信ピン
  DRUM_INTERVAL = 2     # ドラム発音間隔(ms)。小さくするとテンポ速く、大きくするとテンポ遅く
  
  KICK = 36
  SNARE = 38
  CLAP = 39
  HI_HAT_CLOSE = 42
  HI_HAT_OPEN = 46
  HIGH_TOM = 50
  MID_TOM = 47
  LOW_TOM = 41
  CRASH = 49
  
  PATTERN = [  # ドラムパターン。配列を編集して自由にパターン変更可能
    KICK, HI_HAT_CLOSE, SNARE, HI_HAT_CLOSE,
    KICK, HI_HAT_CLOSE, SNARE, HI_HAT_OPEN,
    KICK, MID_TOM, SNARE, HI_HAT_CLOSE,
    KICK, CLAP, SNARE, LOW_TOM
  ]
  
  GT = {36=>1, 38=>2, 39=>3, 49=>5, 52=>5}
  
  def initialize(uart)
    @uart = uart
    @step = 0
    @group_history = [1, 1, 1]
  end
  
  def update
    note = PATTERN[@step % PATTERN.size]
    @uart.write((0x99).chr + note.chr + (0x60).chr)
    
    g = GT[note] || 4
    if g != 5
      @group_history.shift
      @group_history.push(g)
    end
    @step += 1
  end
  
  def group_history
    @group_history
  end
  
  def self.crash(uart)
    uart.write((0x99).chr + CRASH.chr + (0x7F).chr)
  end
end

class LEDVisualizer
  LED_PIN = 22                      # LEDストリップのGPIOピン番号
  LED_COUNT = 30                    # LEDの個数。実際のLED数に合わせて変更
  
  ACCEL_SATURATION_SCALE = 150      # LED彩度のベース値。大きくすると鮮やか、小さくすると淡い色
  ACCEL_BRIGHTNESS_SCALE = 30       # LED輝度のベース値。大きくすると明るい、小さくすると暗い
  
  HUES_DRUM = [nil, 0, 128, 192, 64, 0]  # ドラム演出用の色相配列
  
  def initialize(led_strip)
    @led_strip = led_strip
    @led_colors = Array.new(LED_COUNT, 0)
  end
  
  def update_melody(note_idx, led_offset, saturation, brightness)
    hue = (note_idx * 384 / OtamatoneController::NOTE_RANGE) % 384
    sb = (saturation << 8) | brightness
    color = (hue << 16) | sb
    
    10.times { |i|
      @led_colors[(i * 3 + led_offset) % LED_COUNT] = color
    }
  end
  
  def update_drum(group_history, saturation, brightness)
    sb = (saturation << 8) | brightness
    group_history.each do |g|
      h = HUES_DRUM[g] << 16 | sb
      case g
      when 1
        10.times { |s|
          @led_colors[(s * 3) % LED_COUNT] = h
        }
      when 2
        10.times { |s|
          @led_colors[(s * 3 + 1) % LED_COUNT] = h
        }
      when 3
        10.times { |s|
          @led_colors[(s * 3 + 2) % LED_COUNT] = h
        }
      when 4
        6.times { |i| @led_colors[(i * 5) % LED_COUNT] = h }
      end
    end
  end
  
  def show
    @led_strip.show_hsb_hex(*@led_colors)
  end
  
  def flash
    @led_strip.flash!(LED_COUNT)
  end
  
  def self.calc_saturation(accel_mag)
    (accel_mag + ACCEL_SATURATION_SCALE).clamp(100, 255)
  end
  
  def self.calc_brightness(accel_mag)
    (accel_mag / 2 + ACCEL_BRIGHTNESS_SCALE).clamp(20, 80)
  end
end

speaker = if MUTE
  DPWM.new(OtamatoneController::SPEAKER_PIN, frequency: 262, duty: 1, mute: MUTE)
else
  PWM.new(OtamatoneController::SPEAKER_PIN, frequency: 262, duty: 1)
end

button = GPIO.new(39, GPIO::IN|GPIO::PULL_UP)
led_strip = WS2812.new(RMTDriver.new(LEDVisualizer::LED_PIN))

i2c_bus = I2C.new(unit: :ESP32_I2C0, frequency: 100_000, sda_pin: OtamatoneController::I2C_SDA_PIN, scl_pin: OtamatoneController::I2C_SCL_PIN)
sleep_ms(100)

accel_sensor = MPU6886.new(i2c_bus)
sleep_ms(100)
accel_sensor.accel_range = MPU6886::ACCEL_RANGE_2G
sleep_ms(100)

tof_sensor = VL53L0X.new(i2c_bus)
sleep_ms(100)

md_uart = UART.new(unit: :ESP32_UART1, baudrate: 31250, txd_pin: DrumSequencer::MIDI_TX_PIN, rxd_pin: DrumSequencer::MIDI_RX_PIN)
sleep_ms(10)
md_uart.clear_rx_buffer

md_uart.write((0xB9).chr + (32).chr + (16).chr)
sleep_ms(10)
md_uart.write((0xC9).chr + (0).chr)
sleep_ms(10)

otamatone = OtamatoneController.new(speaker, tof_sensor, accel_sensor)
drum_seq = DrumSequencer.new(md_uart)
led_viz = LEDVisualizer.new(led_strip)

irq = button.irq(GPIO::EDGE_FALL, debounce: 100, capture: {uart: md_uart, viz: led_viz}) do |btn, ev, cap|
  DrumSequencer.crash(cap[:uart])
  cap[:viz].flash
end

tick_count = 0
saturation = 200
brightness = 50

loop do
  IRQ.process
  tick_count += 1
  
  if tick_count % DrumSequencer::DRUM_INTERVAL == 0
    drum_seq.update
  end
  
  if tick_count % 1 == 0
    otamatone.update_distance
  end
  
  if tick_count % 2 == 0
    accel_data = otamatone.update_accel
    
    az = (accel_data[:z] * 100).to_i
    accel_mag = az.abs
    saturation = LEDVisualizer.calc_saturation(accel_mag)
    brightness = LEDVisualizer.calc_brightness(accel_mag)
  end
  
  if otamatone.is_playing
    led_viz.update_melody(otamatone.note_idx, otamatone.led_offset, saturation, brightness)
  else
    led_viz.update_drum(drum_seq.group_history, saturation, brightness)
  end
  
  led_viz.show
  sleep_ms(1)
end

irq.unregister
