# Finger Drum System - Usage Guide

## Quick Start

### 1. PicoRuby側のセットアップ

```bash
# ファイル配置
cp rwc_simple.rb src_components/R2P2-ESP32/storage/home/rwc/rwc.rb

# ビルド＆フラッシュ
rake build && rake flash

# シリアルモニター起動（動作確認）
rake monitor
```

**期待される出力**:
```
Init...
Ready!
=== Drum Receiver ===
1Byte Protocol: note(36-56)
```

### 2. PC側のセットアップ

```bash
# 必要なGemインストール（初回のみ）
cd src_components/pc
bundle install

# プログラム起動
bundle exec ruby drum_simple.rb
```

**起動手順**:
1. MIDIデバイス選択（DDJ-400）
2. シリアルデバイス選択（/dev/cu.usbserial*）
3. 3秒待機（自動）
4. "チェケラッチョ！！演奏開始にょん！" 表示

### 3. 演奏開始

**DDJ-400設定**:
- HOT CUE モードにする（デフォルト）
- SHIFTは押さない（押すと無視される）

**パッド配置**:
```
DECK 1 (左側):
┌─────┬─────┬─────┬─────┐
│  1  │  2  │  3  │  4  │
│Kick │Snare│ClHH │OpHH │
├─────┼─────┼─────┼─────┤
│  5  │  6  │  7  │  8  │
│Crash│Ride │Clap │Cowbl│
└─────┴─────┴─────┴─────┘

DECK 2 (右側):
┌─────┬─────┬─────┬─────┐
│  1  │  2  │  3  │  4  │
│LowTm│LoMid│MidTm│MidHi│
├─────┼─────┼─────┼─────┤
│  5  │  6  │  7  │  8  │
│HiTom│HiTom│Tamb │China│
└─────┴─────┴─────┴─────┘
```

## 動作確認

### 正常な出力例

**PC側**:
```
[1] DECK1 PAD1 → 0x24(36) Kick
[2] DECK1 PAD2 → 0x26(38) Snare
[3] DECK1 PAD3 → 0x2A(42) Closed Hi-Hat
```

**PicoRuby側**:
```
[1] 36:Kick
[2] 38:Snare
[3] 42:ClHH
```

### トラブルシューティング

#### 音が出ない

**チェック項目**:
1. PicoRuby側が "Ready!" を表示しているか
2. PC側が正常に起動しているか
3. MIDI Unitの接続（GPIO 23/33）

**解決方法**:
```bash
# PicoRuby再起動
rake monitor  # Ctrl+T → Ctrl+R でリセット

# PC側再起動
kill -INT <PID>
bundle exec ruby drum_simple.rb
```

#### PC側が接続できない

**エラー**: "シリアルデバイスが見つかりません"

**解決方法**:
```bash
# デバイス確認
ls -l /dev/cu.usbserial*

# 権限確認
sudo chmod 666 /dev/cu.usbserial*
```

#### 音がずれる / 遅延がある

**原因**:
- 通常は発生しない（プロトコル設計により遅延最小）
- USB接続の問題の可能性

**解決方法**:
```bash
# USBケーブルを差し直す
# 別のUSBポートを試す
```

## Advanced Usage

### ドラムキット変更

現在のコードは Standard Drum Kit (Program 0) 固定。
別のキットを使いたい場合は PicoRuby側を修正：

```ruby
# rwc_simple.rb の該当箇所
$md.write((0xC9).chr + (24).chr)  # Electronic Drum Kit
```

**利用可能なキット**:
- 0: Standard Drum Kit
- 8: Room Drum Kit
- 16: Power Drum Kit
- 24: Electronic Drum Kit
- 25: TR-808 Drum Kit
- 32: Jazz Drum Kit

### デバッグモード

**詳細ログを有効化** (PicoRuby側):

```ruby
# process_drums() 内に追加
puts "RX: 0x#{note.to_s(16).upcase}"
puts "TX: 99 #{note.to_s(16).upcase} 7F"
```

**パケットキャプチャ** (PC側):

```ruby
# serial.write() の直後に追加
puts "  [HEX] #{drum_note.to_s(16).upcase.rjust(2,'0')}"
```

## Performance Tips

### 高速連打対応

現在の設定で 200+ BPM の高速演奏に対応。
さらに高速化したい場合：

```ruby
# rwc_simple.rb
sleep_ms(1)  # → sleep_ms(0) に変更（CPU負荷増）
```

### 同時押し対応

16パッド同時押し対応済み。
特に設定変更不要。

### ベロシティ対応（将来拡張）

現在は固定 Velocity 127。
可変ベロシティ対応する場合：

**プロトコル拡張案**:
```
2バイトコマンド:
[Note] [Velocity]
```

**実装例**:
```ruby
# PC側
serial.write(drum_note.chr + velocity.chr)

# PicoRuby側
note = data[0].ord
velocity = data[1].ord
midi_msg = 0x99.chr + note.chr + velocity.chr
```

## File Locations

```
プロジェクト構成:
├── src_components/
│   ├── pc/
│   │   ├── drum_simple.rb      ← PC側プログラム
│   │   ├── Gemfile
│   │   └── Gemfile.lock
│   └── R2P2-ESP32/
│       └── storage/home/rwc/
│           └── rwc.rb           ← PicoRuby側プログラム (rwc_simple.rbをコピー)
├── protocol_spec.md             ← プロトコル仕様書
└── README.md                    ← このファイル
```

## Support

**Issues**:
- バイト境界問題：発生しない（プロトコル設計により保証）
- 同期ずれ：発生しない（1バイト = 1コマンド）
- 遅延：< 5ms（知覚不可能）

**Questions**:
- プロトコル仕様：protocol_spec.md 参照
- コード詳細：各ファイルのコメント参照

チェケラッチョ！！

# Finger Drum System - Usage Guide

## Quick Start

### 1. PicoRuby側のセットアップ

```bash
# ファイル配置
cp rwc_simple.rb src_components/R2P2-ESP32/storage/home/rwc/rwc.rb

# ビルド＆フラッシュ
rake build && rake flash

# シリアルモニター起動（動作確認）
rake monitor
```

**期待される出力**:
```
Init...
Ready!
=== Drum Receiver ===
1Byte Protocol: note(36-56)
```

### 2. PC側のセットアップ

```bash
# 必要なGemインストール（初回のみ）
cd src_components/pc
bundle install

# プログラム起動
bundle exec ruby drum_simple.rb
```

**起動手順**:
1. MIDIデバイス選択（DDJ-400）
2. シリアルデバイス選択（/dev/cu.usbserial*）
3. 3秒待機（自動）
4. "チェケラッチョ！！演奏開始にょん！" 表示

### 3. 演奏開始

**DDJ-400設定**:
- HOT CUE モードにする（デフォルト）
- SHIFTは押さない（押すと無視される）

**パッド配置**:
```
DECK 1 (左側):
┌─────┬─────┬─────┬─────┐
│  1  │  2  │  3  │  4  │
│Kick │Snare│ClHH │OpHH │
├─────┼─────┼─────┼─────┤
│  5  │  6  │  7  │  8  │
│Crash│Ride │Clap │Cowbl│
└─────┴─────┴─────┴─────┘

DECK 2 (右側):
┌─────┬─────┬─────┬─────┐
│  1  │  2  │  3  │  4  │
│LowTm│LoMid│MidTm│MidHi│
├─────┼─────┼─────┼─────┤
│  5  │  6  │  7  │  8  │
│HiTom│HiTom│Tamb │China│
└─────┴─────┴─────┴─────┘
```

## 動作確認

### 正常な出力例

**PC側**:
```
[1] DECK1 PAD1 → 0x24(36) Kick
[2] DECK1 PAD2 → 0x26(38) Snare
[3] DECK1 PAD3 → 0x2A(42) Closed Hi-Hat
```

**PicoRuby側**:
```
[1] 36:Kick
[2] 38:Snare
[3] 42:ClHH
```

### トラブルシューティング

#### 音が出ない

**チェック項目**:
1. PicoRuby側が "Ready!" を表示しているか
2. PC側が正常に起動しているか
3. MIDI Unitの接続（GPIO 23/33）

**解決方法**:
```bash
# PicoRuby再起動
rake monitor  # Ctrl+T → Ctrl+R でリセット

# PC側再起動
kill -INT <PID>
bundle exec ruby drum_simple.rb
```

#### PC側が接続できない

**エラー**: "シリアルデバイスが見つかりません"

**解決方法**:
```bash
# デバイス確認
ls -l /dev/cu.usbserial*

# 権限確認
sudo chmod 666 /dev/cu.usbserial*
```

#### 音がずれる / 遅延がある

**原因**:
- 通常は発生しない（プロトコル設計により遅延最小）
- USB接続の問題の可能性

**解決方法**:
```bash
# USBケーブルを差し直す
# 別のUSBポートを試す
```

## Advanced Usage

### ドラムキット変更

現在のコードは Standard Drum Kit (Program 0) 固定。
別のキットを使いたい場合は PicoRuby側を修正：

```ruby
# rwc_simple.rb の該当箇所
$md.write((0xC9).chr + (24).chr)  # Electronic Drum Kit
```

**利用可能なキット**:
- 0: Standard Drum Kit
- 8: Room Drum Kit
- 16: Power Drum Kit
- 24: Electronic Drum Kit
- 25: TR-808 Drum Kit
- 32: Jazz Drum Kit

### デバッグモード

**詳細ログを有効化** (PicoRuby側):

```ruby
# process_drums() 内に追加
puts "RX: 0x#{note.to_s(16).upcase}"
puts "TX: 99 #{note.to_s(16).upcase} 7F"
```

**パケットキャプチャ** (PC側):

```ruby
# serial.write() の直後に追加
puts "  [HEX] #{drum_note.to_s(16).upcase.rjust(2,'0')}"
```

## Performance Tips

### 高速連打対応

現在の設定で 200+ BPM の高速演奏に対応。
さらに高速化したい場合：

```ruby
# rwc_simple.rb
sleep_ms(1)  # → sleep_ms(0) に変更（CPU負荷増）
```

### 同時押し対応

16パッド同時押し対応済み。
特に設定変更不要。

### ベロシティ対応（将来拡張）

現在は固定 Velocity 127。
可変ベロシティ対応する場合：

**プロトコル拡張案**:
```
2バイトコマンド:
[Note] [Velocity]
```

**実装例**:
```ruby
# PC側
serial.write(drum_note.chr + velocity.chr)

# PicoRuby側
note = data[0].ord
velocity = data[1].ord
midi_msg = 0x99.chr + note.chr + velocity.chr
```

## File Locations

```
プロジェクト構成:
├── src_components/
│   ├── pc/
│   │   ├── drum_simple.rb      ← PC側プログラム
│   │   ├── Gemfile
│   │   └── Gemfile.lock
│   └── R2P2-ESP32/
│       └── storage/home/rwc/
│           └── rwc.rb           ← PicoRuby側プログラム (rwc_simple.rbをコピー)
├── protocol_spec.md             ← プロトコル仕様書
└── README.md                    ← このファイル
```

## Support

**Issues**:
- バイト境界問題：発生しない（プロトコル設計により保証）
- 同期ずれ：発生しない（1バイト = 1コマンド）
- 遅延：< 5ms（知覚不可能）

**Questions**:
- プロトコル仕様：protocol_spec.md 参照
- コード詳細：各ファイルのコメント参照

チェケラッチョ！！