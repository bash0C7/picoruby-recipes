# 自動演奏！
DEBUG = false  # デバッグモード

require 'ws2812'
require 'gpio'
require 'irq'
require 'uart'

class DrumMachine
  MIDI_TX_PIN = 22
  MIDI_RX_PIN = 19
  DRUM_INTERVAL = 10     # ドラム発音間隔(ms)。小さくすると速く
  
  KICK = 36
  SNARE = 38
  CLAP = 39
  HI_HAT_CLOSE = 42
  HI_HAT_OPEN = 46
  HIGH_TOM = 50
  MID_TOM = 47
  LOW_TOM = 41
  CRASH = 49
  
  # 基本パターン（8ビート2小節。複数の音が同時に鳴るステップあり）
  BASIC_PATTERN = [
    [LOW_TOM],                  # 0: 1拍表
    [HI_HAT_CLOSE],             # 1: 1拍裏
    [],                         # 2: 2拍表
    [HI_HAT_CLOSE, MID_TOM],   # 3: 2拍裏
    [CLAP],                     # 4: 3拍表
    [HI_HAT_CLOSE],             # 5: 3拍裏
    [HI_HAT_OPEN],              # 6: 4拍表
    [HI_HAT_CLOSE, LOW_TOM],   # 7: 4拍裏
    [LOW_TOM],                  # 8: 5拍表
    [HI_HAT_CLOSE],             # 9: 5拍裏
    [CLAP],                     # 10: 6拍表
    [HI_HAT_CLOSE, MID_TOM],   # 11: 6拍裏
    [],                         # 12: 7拍表
    [HI_HAT_CLOSE],             # 13: 7拍裏
    [HI_HAT_OPEN],              # 14: 8拍表
    [HI_HAT_CLOSE, LOW_TOM]    # 15: 8拍裏
  ]

  # フィルインパターン（4拍。ドラムロール→CRASHで締める派手なフィル）
  FILL_IN_PATTERN = [
    [KICK],                     # 0: フィルイン開始
    [SNARE, HIGH_TOM],          # 1: ドラムロール開始
    [KICK, CLAP],               # 2: 盛り上がり
    [MID_TOM, LOW_TOM],         # 3: タムロール
    [KICK],                     # 4: 再度キック
    [SNARE, CRASH],             # 5: スネア＋クラッシュで加速
    [KICK, HIGH_TOM, CLAP],    # 6: トリプル音で最高潮
    [CRASH]                     # 7: クラッシュで締める
  ]
  
  GT = {36=>1, 38=>2, 39=>3, 49=>5, 52=>5}
  
  def initialize(uart)
    @uart = uart
    @step = 0
    @group_history = [1, 1, 1]
    @fill_in_mode = false        # フィルイン中フラグ
    @fill_in_step = 0            # フィルイン進行カウンタ
    @current_pattern = BASIC_PATTERN  # 現在のパターン
    @midi_buffer = []            # 外部MIDI受信バッファ
    @external_group_history = [4, 4, 4]  # 外部MIDIグループ履歴
  end
  
  def update
    notes = @current_pattern[@step % @current_pattern.size]

    # 複数の音を鳴らす
    last_note = nil
    notes.each do |note|
      @uart.write((0x99).chr + note.chr + (0x60).chr)
      last_note = note
    end

    # グループ履歴更新（最後の音のグループを記録）
    if last_note
      g = GT[last_note] || 4
      if g != 5
        @group_history.shift
        @group_history.push(g)
      end
    end

    @step += 1

    # フィルイン完了判定
    if @fill_in_mode
      @fill_in_step += 1
      if @fill_in_step >= FILL_IN_PATTERN.size
        @fill_in_mode = false
        @fill_in_step = 0
        @current_pattern = BASIC_PATTERN
      end
    end
  end
  
  def group_history
    @group_history
  end

  def step
    @step
  end

  def play_fill_in
    @fill_in_mode = true
    @fill_in_step = 0
    @current_pattern = FILL_IN_PATTERN
  end

  def external_group_history
    @external_group_history
  end

  def crash
    @uart.write((0x99).chr + CRASH.chr + (0x7F).chr)
  end

  def process_external_midi
    # UART受信バッファを全て読む
    while @uart.bytes_available > 0
      data = @uart.read(1)
      next unless data && data.length == 1

      byte_val = data[0].ord
      @midi_buffer.push(byte_val)

      # バッファサイズ制限
      if @midi_buffer.length > 12
        @midi_buffer.shift
      end

      # MIDIメッセージ解析（3バイト）
      if @midi_buffer.length >= 3
        status = @midi_buffer[0]

        # ステータスバイト判定（0x80以上）
        if status >= 0x80
          case status & 0xF0
          when 0x90  # Note On
            note = @midi_buffer[1]
            velocity = @midi_buffer[2]

            # ソフトスルー: そのまま送り返す
            @uart.write(status.chr + note.chr + velocity.chr)

            # グループ履歴更新（velocity > 0のみ）
            if velocity > 0
              g = GT[note] || 4
              if g != 5  # フラッシュは履歴に残さない
                @external_group_history.shift
                @external_group_history.push(g)
              end
            end

          when 0x80  # Note Off
            note = @midi_buffer[1]
            velocity = @midi_buffer[2]
            @uart.write(status.chr + note.chr + velocity.chr)
          end

          # 処理済みメッセージを削除
          @midi_buffer.shift(3)
        else
          # 不正なステータス: 1バイト削除
          @midi_buffer.shift
        end
      end
    end
  end
end

class RhythmLEDVisualizer
  LED_PIN = 33
  LED_COUNT = 30
  
  HUES_DRUM = [nil, 0, 128, 192, 64, 0]
  
  def initialize(led_strip)
    @led_strip = led_strip
    @led_colors = Array.new(LED_COUNT, 0)
  end
  
  def update(auto_group_history, external_group_history, step)
    # 2つのグループ履歴を統合（交互に配置）
    combined_history = []
    [auto_group_history, external_group_history].each do |history|
      history.each { |g| combined_history.push(g) }
    end

    # ステップに基づいてオフセットを計算（毎拍ひとつずつシフト）
    pattern_offset = step % LED_COUNT

    saturation = 255
    brightness = 80
    sb = (saturation << 8) | brightness

    # 全 LED に対して combined_history の色を循環させる
    LED_COUNT.times do |i|
      # 各 LED にオフセット付きで combined_history から色を選ぶ
      color_idx = (i + pattern_offset) % combined_history.size
      g = combined_history[color_idx]
      hue = HUES_DRUM[g]

      @led_colors[i] = (hue << 16) | sb
    end
  end
  
  def show
    @led_strip.show_hsb_hex(*@led_colors)
  end
  
  def flash
    @led_strip.flash!(LED_COUNT)
  end
end

button = GPIO.new(39, GPIO::IN|GPIO::PULL_UP)
led_strip = WS2812.new(RMTDriver.new(RhythmLEDVisualizer::LED_PIN))

md_uart = UART.new(unit: :ESP32_UART1, baudrate: 31250, txd_pin: DrumMachine::MIDI_TX_PIN, rxd_pin: DrumMachine::MIDI_RX_PIN)
sleep_ms(10)
md_uart.clear_rx_buffer

md_uart.write((0xB9).chr + (32).chr + (16).chr)
sleep_ms(10)
md_uart.write((0xC9).chr + (0).chr)
sleep_ms(10)

drum = DrumMachine.new(md_uart)
led_viz = RhythmLEDVisualizer.new(led_strip)

irq = button.irq(GPIO::EDGE_FALL, debounce: 100, capture: {drum: drum, viz: led_viz}) do |btn, ev, cap|
  cap[:drum].play_fill_in  # フィルイン再生開始
  cap[:viz].flash          # LEDフラッシュ
end

tick_count = 0

loop do
  IRQ.process
  tick_count += 1

  if tick_count % DrumMachine::DRUM_INTERVAL == 0
    drum.update
  end

  # 外部MIDI受信（毎フレーム）
  drum.process_external_midi

  # LED更新
  if tick_count % DrumMachine::DRUM_INTERVAL == 0
    led_viz.update(drum.group_history, drum.external_group_history, drum.step)
    led_viz.show
  end

  sleep_ms(1)
end

irq.unregister
