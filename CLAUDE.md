# PicoRuby ESP32 Project Instructions

ATOM Matrix (ESP32-PICO-D4) + R2P2-ESP32 (PicoRuby runtime) embedded development configuration.

## Core Principles

<simplicity_first>
Avoid complexity. Think carefully before implementing.

**Embedded System Constraints**:
- Shallow nesting only (memory critical: 520KB RAM available)
- Pre-allocate arrays, avoid dynamic allocation
- No complex class hierarchies, exception handling, or deep function calls without explicit user request
- Write simple, linear code by default

**PicoRuby vs CRuby**:
- "Ruby" = CRuby (standard Ruby)
- "PicoRuby" = mruby/c subset (limited stdlib, no bundler, no RubyGems.org)
- ALWAYS think within PicoRuby constraints for .rb files
- .rb files run on PicoRuby/mruby (NOT CRuby)
</simplicity_first>

<output_tone>
**日本語で出力すること**:
- **絶対に日本語で応答・プラン提示すること**
- 通常時: 語尾に「ピョン。」をつけて可愛く
- 盛り上がってきたら:「チェケラッチョ！！」と叫ぶ
- コード内コメント: 日本語、体言止め
- ドキュメント(.md): 英語で記述
- Git commit: 英語、命令形
</output_tone>

<default_to_action>
When implementing changes:
1. Implement proactively WITHOUT asking "should I...?" or "shall I...?"
2. Commit changes IMMEDIATELY after implementation (MUST use subagent `commit`)
3. DO NOT push to remote unless user explicitly requests
4. User will verify functionality AFTER commit (not before)

**Commit immediately to prevent data loss in case of errors**
</default_to_action>

<investigate_before_answering>
**NEVER speculate about code you have not opened**.

When user references files, GPIO, hardware, or existing code:
1. **MUST read files first** before answering
2. **MUST use subagent `explore`** for:
   - Code investigation/exploration
   - Understanding current implementation during plan mode
   - Complex dependency analysis
3. Give grounded, hallucination-free answers based on actual code
4. Read multiple files in parallel when investigating related components
</investigate_before_answering>

<use_parallel_tool_calls>
When reading multiple independent files or searching codebase:
- Read files in parallel (single message, multiple Read tool calls)
- Run Grep searches in parallel when possible
- NEVER use placeholders - wait for actual results if dependencies exist
</use_parallel_tool_calls>

<extended_thinking>
For complex problems:
1. Use "think hard" for multi-step reasoning
2. Reflect carefully on tool results before proceeding
3. Plan iterations based on new information discovered
</extended_thinking>

## Commands

⚠️ **IMPORTANT**: Do NOT execute `rake` commands autonomously without user approval.

**Permissions** (configured in `.claude/settings.local.json`):
- ✅ **Allowed**: `rake monitor`, `rake check_env` (read-only operations)
- ❓ **Ask first**: `rake build`, `rake cleanbuild`, `rake flash` (time-consuming/hardware operations)
- 🚫 **Denied**: `rake init`, `rake update`, `rake buildall` (contain destructive git operations)

```bash
rake init        # Initial setup (DENIED - contains git reset --hard)
rake build       # Build (ASK - build operation)
rake buildall    # Build all (DENIED - same as cleanbuild)
rake cleanbuild  # Clean build (ASK - destructive clean)
rake check_env   # Environment check (ALLOWED - read-only)
rake flash       # Flash to ESP32 (ASK - hardware write)
rake monitor     # Monitor serial output (ALLOWED - debug capture)
rake update      # Update (DENIED - contains git reset --hard)
```

**Rationale**:
- `rake monitor` is allowed for direct debug information capture during development
- Build/flash operations require confirmation to prevent accidental time-consuming operations
- Operations containing `git reset --hard` are completely denied to protect work in progress

## Code Style

**Ruby (.rb files - PicoRuby/mruby)**:
- Embedded constraints: shallow nesting, simplicity first
- Memory-focused: pre-allocate arrays, avoid dynamic allocation
- Comments: Japanese, noun-ending style (体言止め)
- PicoRuby/mruby stdlib ONLY (no CRuby features, no gems)

**Documentation (.md files)**:
- English

**Git Commits**:
- English, imperative mood
- ⚠️ **IMPORTANT**: MUST use subagent `commit` for all commits
- Claude Code MUST NOT execute git commit commands directly
- **Subagent commit workflow**:
  - Proposes commit message AND executes actual commit
  - Completes both git add + git commit
  - ⚠️ **FORBIDDEN**: git push, git push --force (remote operations absolutely prohibited)

## Workflow

<workflow_steps>
0. **Investigation Phase** (MUST use subagent `explore`):
   - Code investigation/exploration
   - Current code review during plan mode
   - Complex dependency understanding

1. **Complex Problem Solving**:
   - Use "think hard" for extended reasoning

2. **Implementation**:
   - Small, incremental changes

3. **Immediate Auto-Commit** (subagent `commit`):
   - Commit BEFORE user testing (prevent data loss on errors)
   - NEVER skip this step

4. **User Verification**:
   - Ask user to verify functionality
</workflow_steps>

## Architecture

- **Arduino C++**: Initialization, ESP-IDF integration
- **PicoRuby**: Application logic, LED control, sensors
- **Build System**: ESP-IDF + R2P2-ESP32

**File Locations**:
- Ruby apps: `src_components/R2P2-ESP32/storage/home/`
- Build config: `build_config/xtensa-esp.rb`

## Finger Drum Project

Real-time drum performance system using DDJ-400 controller + ATOM Matrix.

**Detailed Information**: See `.claude/skills/finger-drum/SKILL.md`

**PicoRuby Application (Auto-executed on boot)**:
- **Entry Point**: `src_components/R2P2-ESP32/storage/home/app.rb` (main application, auto-runs on ESP32 startup)
  - Handles UART communication with PC
  - Controls MIDI output to synthesizer
  - Manages LED visualization (WS2812 strip, 60 LEDs)
  - Reads accelerometer (MPU6886) for dynamic color effects
  - Processes button input (GPIO 39) for crash cymbal trigger

**Related Implementation Files**:
- Design/README: `src_components/pc/drum_readme.rb`
- Protocol spec: `src_components/pc/drum_protcolspec.md`
- PC MIDI version: `src_components/pc/drum_midi.rb`
- PC keyboard version: `src_components/pc/drum_pc.rb`
- PicoRuby compact reference: `src_components/R2P2-ESP32/storage/home/rwcc.rb`
- PicoRuby full reference: `src_components/R2P2-ESP32/storage/home/rwc.rb`

Auto-loads when keywords mentioned: finger drum, DDJ-400, drum performance, MIDI performance

## Auto-Referenced Information

Claude automatically loads detailed information when asked about:

- **GPIO, LED, sensors** → Hardware specifications auto-referenced
- **PicoRuby constraints, memory optimization** → Development guide auto-referenced
- **Finger Drum** → Finger drum system info auto-referenced

No need to memorize! Auto-loaded only when needed.

## Constraints

- **Memory**: 520KB RAM (excluding system usage)
- **Ruby Libraries**: Standard library only (no gems)
- **Code**: Shallow nesting, avoid complex classes
- **Character Encoding**: UTF-8

## Environment

- **ESP-IDF**: `$HOME/esp/esp-idf/` (auto-configured by rake)
- **Flash Speed**: 115200 bps

---

**Note**: Keep this config file concise. Detailed information auto-loads only when needed.

# @src_components/R2P2-ESP32/storage/home/otpwm.rb

PWM版ノイズ・アンビエント楽器 実装仕様

## プロジェクト概要
M5Stack ATOM Matrix上でPicoRuby(mruby/c)を使用し、距離センサーと加速度センサーを用いた電子ノイズ楽器を実装する。攻撃的な電子音と連動したアンビエントなLED演出が特徴。

## ハードウェア構成
### デバイス
- メインボード: M5Stack ATOM Matrix
- 拡張ボード: ATOM Matrix用拡張ボード
- 距離センサー: VL53L0X（Unit ToF）
- 加速度センサー: MPU6886（ATOM Matrix内蔵）
- スピーカー: PWM制御Grove互換スピーカー
- LED: WS2812 LEDストリップ 30個

### ピン配置
- J3 (I2C): SDA=GPIO25, SCL=GPIO21 → VL53L0X + MPU6886
- J4 (アナログ): GPIO33 → PWMスピーカー
- J5 (シリアル): GPIO22 → WS2812 LEDストリップ
- ボタン: GPIO39（ATOM Matrix内蔵）

## 機能仕様

### 音響制御
1. **距離→周波数マッピング**
   - 測定範囲: 20mm〜250mm
   - 周波数範囲: 100Hz〜2000Hz（ノイズミュージック的な広域）
   - マッピング: 近い=低音、遠い=高音
   - 範囲外: duty=1で極小音量（連続発振維持）

2. **加速度センサー→音色制御**
   - X軸: duty比変化（25%〜60%、音量・音色変化）
   - Y軸: 周波数ビブラート（±50Hz）
   - Z軸: カットオフ風効果（dutyに微調整を追加）

3. **平滑化処理**
   - 距離: IIRFilterで平滑化
   - duty変化: DUTY_SMOOTH_FACTOR=3で滑らか遷移

### LED演出
1. **ダイナミック波形表現**
   - 全30個のLEDを使用
   - 色相: 周波数に連動（100Hz=0度、2000Hz=384度）
   - 彩度: duty比に連動
   - 輝度: duty比に連動
   - 波形オフセット: 毎フレーム+1で流れる演出
   - 加速度影響: XYZ合計値で色相に揺らぎ追加

2. **ボタン操作**
   - ボタン押下: LEDフラッシュのみ（音響変化なし）

## 技術的制約

### PicoRuby/mruby/c制約
- メモリ制約が厳しい
- 大きな配列操作は避ける
- 浮動小数点演算は整数演算で代替
- クラス化は最小限（必要な場合のみ）
- 例外処理は使用しない
- bundler、RubyGems.org不使用

### コーディング規約
- シンプルに書き下す（原則として複雑な関数化・クラス化を避ける）
- 日本語コメントで主要定数を解説
- グローバル定数は冒頭にまとめる
- DEBUGフラグで音量・ログ出力を制御
- MUTEフラグでPWM音出力を制御

## パラメータ設定

### 音響パラメータ
```rubyDEBUG = false  # true=小音量+デバッグ出力、false=通常音量
MUTE = false   # true=音を出さずログ出力のみ、false=実際に音を出すDIST_MIN = 20         # 最小距離(mm)
DIST_MAX = 250        # 最大距離(mm)
FREQ_MIN = 100        # 最低周波数(Hz)
FREQ_MAX = 2000       # 最高周波数(Hz)BASE_DUTY = DEBUG ? 15 : 40           # 基準duty比(%)
DUTY_MIN = DEBUG ? 10 : 25            # 最小duty比(%)
DUTY_MAX = DEBUG ? 25 : 60            # 最大duty比(%)
DUTY_DELTA_SCALE = DEBUG ? 10 : 20    # X軸→duty変化の感度VIBRATO_SCALE = 50                    # Y軸→ビブラート強さ(Hz)
CUTOFF_SCALE = 30                     # Z軸→カットオフ風効果
DUTY_SMOOTH_FACTOR = 3                # duty変化の滑らかさ

### LEDパラメータ
```rubyLED_PIN = 22
LED_COUNT = 30

## 実装要件

### クラス設計
1. **NoiseInstrument**: 距離・加速度→音響制御
   - `update_distance()`: 距離測定・周波数設定
   - `update_accel()`: 加速度測定・duty/ビブラート制御

2. **AmbientLEDVisualizer**: LED演出
   - `update()`: 周波数・duty・加速度からLED色計算
   - `show()`: LED表示
   - `flash()`: ボタン用フラッシュ

### メインループ処理
- 1msごと: 距離測定・周波数更新
- 2msごと: 加速度測定・duty更新・LED更新
- IRQ: ボタン割り込み処理

## デバッグ用DPWMクラス
MUTEモード用のダミークラス。PWMの代わりにログ出力のみ行う。

## 期待される動作
- 手を近づけると低い音
- 手を遠ざけると高い攻撃的な電子音
- 本体を傾けると音色が変化
- LEDは音に連動して波打つように色変化
- ボタンでLEDフラッシュ

## 納品物
- 単一の.rbファイル
- 冒頭にDEBUG/MUTEフラグ配置
- 主要定数に日本語コメント
- クラスは2つ（NoiseInstrument、AmbientLEDVisualizer）

# @src_components/R2P2-ESP32/storage/home/otmidi.rb 

MIDI版リズムマシン 実装仕様

## プロジェクト概要
M5Stack ATOM Matrix上でPicoRuby(mruby/c)を使用し、MIDI音源モジュールを制御する自動ドラムマシンを実装する。リズムパターンに同期したLED演出が特徴。

## ハードウェア構成
### デバイス
- メインボード: M5Stack ATOM Matrix
- MIDI音源: SAM2695等のMIDI Unitモジュール
- LED: WS2812 LEDストリップ 30個

### ピン配置
- 本体Grove: GPIO26(TX), GPIO32(RX) → MIDI Unit
- J5 (シリアル): GPIO22 → WS2812 LEDストリップ
- ボタン: GPIO39（ATOM Matrix内蔵）

## 機能仕様

### MIDI制御
1. **ドラムパターン自動演奏**
   - チャンネル10（ドラム専用）使用
   - 16ステップパターンをループ再生
   - テンポ: DRUM_INTERVAL（デフォルト2ms/ステップ）

2. **使用ドラム音**
   - KICK (36): キックドラム
   - SNARE (38): スネアドラム
   - CLAP (39): ハンドクラップ
   - HI_HAT_CLOSE (42): クローズドハイハット
   - HI_HAT_OPEN (46): オープンハイハット
   - HIGH_TOM (50): ハイタム
   - MID_TOM (47): ミッドタム
   - LOW_TOM (41): ロータム
   - CRASH (49): クラッシュシンバル（ボタン用）

3. **MIDI初期化**
   - Bank Select LSB (CC#32) = 16 (Power Kit)
   - Program Change = 0

### LED演出
1. **リズムパターン同期**
   - ドラム音ごとにグループ分け（GT定数）
   - グループ履歴（直近3音）を保持
   - 各グループに固有の色相・LED配置パターン

2. **色相配列**
   - Group 1: 赤系（0度）
   - Group 2: シアン系（128度）
   - Group 3: マゼンタ系（192度）
   - Group 4: 黄系（64度）
   - Group 5: フラッシュ専用

3. **ボタン操作**
   - ボタン押下: クラッシュシンバル発音 + LEDフラッシュ

## 技術的制約

### PicoRuby/mruby/c制約
- メモリ制約が厳しい
- 大きな配列操作は避ける
- 浮動小数点演算は整数演算で代替
- クラス化は最小限（必要な場合のみ）
- 例外処理は使用しない
- bundler、RubyGems.org不使用

### コーディング規約
- シンプルに書き下す（原則として複雑な関数化・クラス化を避ける）
- 日本語コメントで主要定数を解説
- グローバル定数は冒頭にまとめる
- DEBUGフラグでログ出力を制御

## パラメータ設定

### MIDIパラメータ
```ruby
DEBUG = false  # true=デバッグ出力、false=出力なし

MIDI_TX_PIN = 26      # MIDI送信ピン
MIDI_RX_PIN = 32      # MIDI受信ピン
DRUM_INTERVAL = 2     # ドラム発音間隔(ms)。小さくすると速く

PATTERN = [  # 16ステップドラムパターン
  KICK, HI_HAT_CLOSE, SNARE, HI_HAT_CLOSE,
  KICK, HI_HAT_CLOSE, SNARE, HI_HAT_OPEN,
  KICK, MID_TOM, SNARE, HI_HAT_CLOSE,
  KICK, CLAP, SNARE, LOW_TOM
]

GT = {36=>1, 38=>2, 39=>3, 49=>5, 52=>5}  # ドラム音→グループマッピング
```

### LEDパラメータ
```ruby
LED_PIN = 22
LED_COUNT = 30

HUES_DRUM = [nil, 0, 128, 192, 64, 0]  # グループ別色相配列
```

## 実装要件

### クラス設計
1. **DrumMachine**: MIDIドラム制御
   - `update()`: 次のドラム音を発音、グループ履歴更新
   - `crash()`: クラッシュシンバル発音（ボタン用）
   - `group_history`: 直近3音のグループ履歴を返す

2. **RhythmLEDVisualizer**: LED演出
   - `update(group_history)`: グループ履歴からLED色計算
   - `show()`: LED表示
   - `flash()`: ボタン用フラッシュ

### メインループ処理
- DRUM_INTERVALごと: ドラムパターン進行・発音
- 1msごと: LED更新
- IRQ: ボタン割り込み処理

## UART通信仕様
- ボーレート: 31250（MIDI標準）
- Note On: 0x99 + note + velocity
- Bank Select: 0xB9 + 32 + 16
- Program Change: 0xC9 + 0

## 期待される動作
- 起動と同時にドラムパターン自動演奏開始
- リズムに合わせてLEDが色変化
- ボタンでクラッシュシンバル+フラッシュ
- 加速度センサーは使用しない

## 納品物
- 単一の.rbファイル
- 冒頭にDEBUGフラグ配置
- 主要定数に日本語コメント
- クラスは2つ（DrumMachine、RhythmLEDVisualizer）

