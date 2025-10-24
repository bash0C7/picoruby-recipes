# PicoRuby Finger Drum + FX Control v2

## 概要

DDJ-400とATOM Matrixでリアルタイムなドラムパフォーマンスとエフェクトコントロールを実現します。FILTERノブで残響（リバーブ）とレゾナンスを直感的に操作できます。

## 新機能（v2）

### ✨ DECK1 FILTER → 残響コントロール
- FILTERノブを回すとリバーブ量を10段階で調整
- 左回し：ドライ（残響なし）
- 右回し：ウェット（残響たっぷり）

### ✨ DECK2 FILTER → レゾナンスコントロール
- FILTERノブを回すとレゾナンス（音の響き）を10段階で調整
- 左回し：こもった音
- 右回し：キンキンした響き

## ハードウェア構成

```
DDJ-400
├── DECK1 PADs: ドラムトリガー（キック/スネア/HH等）
├── DECK1 FILTER: 残響コントロール（CC#23）
├── DECK2 PADs: タム＆パーカッショントリガー
└── DECK2 FILTER: レゾナンスコントロール（CC#24）
    ↓ USB
PC (CRuby)
    ↓ UART (115200bps, 1byte protocol)
ATOM Matrix
├── LED Strip (GPIO 22): 60個のWS2812 LEDs
└── MIDI Unit (GPIO 23/33): 音源モジュール (31250bps)
```

## セットアップ

### 1. PC側の準備

```bash
cd src_components/pc
bundle install
```

### 2. ATOM Matrix側の準備

```bash
# demo_fx.rbをATOM Matrixに配置
cp demo_fx.rb src_components/R2P2-ESP32/storage/home/

# ビルド＆フラッシュ
rake build
rake flash
```

### 3. 実行

**PC側**:
```bash
ruby drum_fx_pc.rb
```

**起動後の表示例**:
```
=== DDJ-400 Finger Drum + FX Control にょん！===

【通信プロトコル v2】
  ドラムノート: 36-56 (1byte)
  残響レベル:   1-10 (1byte, DECK1 FILTER)
  レゾナンス:   11-20 (1byte, DECK2 FILTER)

【DECK 1 - 基本ドラムキット + 残響コントロール】
  PAD1-8: キック/スネア/HH/シンバル等
  FILTER: 残響（リバーブ）レベル 0-9

【DECK 2 - タム＆パーカッション + レゾナンスコントロール】
  PAD1-8: 各種タム/タンバリン/チャイナ
  FILTER: レゾナンス（音の響き）レベル 0-9

チェケラッチョ！！演奏開始にょん！
```

## 使い方

### 基本演奏

**DECK1（左側）**:
- PAD1: キック (Kick)
- PAD2: スネア (Snare)
- PAD3: クローズハイハット (Closed Hi-Hat)
- PAD4: オープンハイハット (Open Hi-Hat)
- PAD5: クラッシュシンバル (Crash Cymbal)
- PAD6: ライドシンバル (Ride Cymbal)
- PAD7: ハンドクラップ (Hand Clap)
- PAD8: カウベル (Cowbell)

**DECK2（右側）**:
- PAD1: ロータム (Low Tom)
- PAD2: ローミッドタム (Low-Mid Tom)
- PAD3: ミッドタム (Mid Tom)
- PAD4: ミッドハイタム (Mid-Hi Tom)
- PAD5: ハイタム (Hi Tom)
- PAD6: ハイタム (High Tom)
- PAD7: タンバリン (Tambourine)
- PAD8: チャイナシンバル (Chinese Cymbal)

### エフェクトコントロール

#### 残響（リバーブ）調整
**DECK1のFILTERノブを使用**

| ノブ位置 | 効果 | 用途 |
|---------|------|------|
| 左端 | ドライ（残響なし） | タイトなビート |
| 中央 | 中間的な残響 | バランス型 |
| 右端 | ウェット（残響たっぷり） | 空間的な演出 |

**使用例**:
1. 基本ビートはドライ（左側）で刻む
2. フィルインでノブを右に回してドラマチックに
3. ブレイク後に左に戻してタイトに

#### レゾナンス調整
**DECK2のFILTERノブを使用**

| ノブ位置 | 効果 | 用途 |
|---------|------|------|
| 左端 | こもった音 | 落ち着いた響き |
| 中央 | 自然な響き | 標準 |
| 右端 | キンキンした音 | アグレッシブ |

**使用例**:
1. タムの響きを強調（右側）
2. スネアの切れ味を調整（中央-右）
3. ソフトな雰囲気は左側

### パフォーマンステクニック

#### 1. 動的な残響コントロール
```
基本パターン（ドライ）
  ↓
フィルイン開始
  ↓
残響を徐々に上げる（FILTER右回し）
  ↓
クラッシュで最大
  ↓
次のセクションでドライに戻す
```

#### 2. レゾナンスでアクセント
```
通常のタム（中央）
  ↓
強調したいタムで右に回す
  ↓
響きが強調されてインパクト増
  ↓
元に戻す
```

#### 3. 同時操作
- 左手：DECK1 FILTERで残響調整
- 右手：DECK2 PADsでタム連打
- 両手：ダイナミックな音色変化

## プロトコル詳細

### 1byte通信プロトコル v2
```
36-56  : ドラムノート（21種類）
1-10   : 残響レベル（10段階）
11-20  : レゾナンスレベル（10段階）
```

**特徴**:
- すべて1byteで完結
- 同期エラーなし
- 超低レイテンシ（< 5ms）

### PC側処理

**ドラム送信**:
```ruby
drum_note = 36  # Kick
serial.write(drum_note.chr)
```

**残響送信**（DECK1 FILTER CC#23受信時）:
```ruby
cc_value = midi_bytes[2]  # 0-127
level = (cc_value * 10 / 128).to_i  # 0-9
send_value = level + 1  # 1-10
serial.write(send_value.chr)
```

**レゾナンス送信**（DECK2 FILTER CC#24受信時）:
```ruby
cc_value = midi_bytes[2]  # 0-127
level = (cc_value * 10 / 128).to_i  # 0-9
send_value = level + 11  # 11-20
serial.write(send_value.chr)
```

### PicoRuby側処理

**コマンド解析**:
```ruby
cmd = uart.read(1)[0].ord

case cmd
when 36..56
  # ドラムノート → MIDI Note On
  midi_msg = 0x99.chr + cmd.chr + 0x7F.chr
  midi_uart.write(midi_msg)
  
when 1..10
  # 残響 → MIDI CC#91
  level = cmd - 1  # 0-9
  cc_value = (level * 127 / 9).to_i
  midi_cc = 0xB9.chr + 91.chr + cc_value.chr
  midi_uart.write(midi_cc)
  
when 11..20
  # レゾナンス → MIDI CC#71
  level = cmd - 11  # 0-9
  cc_value = (level * 127 / 9).to_i
  midi_cc = 0xB9.chr + 71.chr + cc_value.chr
  midi_uart.write(midi_cc)
end
```

## トラブルシューティング

### 残響が効かない
- MIDI Unitが CC#91 (Reverb Send) に対応しているか確認
- SAM2695は対応済み

### レゾナンスが効かない
- MIDI Unitが CC#71 (Resonance) に対応しているか確認
- フィルター機能を持つ音源が必要

### ノブが反応しない
- DDJ-400のFILTERノブがCC#23/24を送信しているか確認
- MIDIモニターツール（MIDI-OX等）で確認可能

## 出力例

**ドラム演奏時**:
```
[1] 🥁 DECK1 PAD1 → Kick (36)
[2] 🥁 DECK1 PAD2 → Snare (38)
[3] 🥁 DECK1 PAD3 → Closed Hi-Hat (42)
```

**エフェクト調整時**:
```
[4] 🌊 REVERB: Level 3 (raw:48 → 4)
[5] ✨ RESONANCE: Level 7 (raw:112 → 18)
```

## パフォーマンスのコツ

1. **残響は大胆に**: フィルインで一気に右端まで回す
2. **レゾナンスは繊細に**: 微調整で音色が変わる
3. **両手使い**: 左手でエフェクト、右手でドラム
4. **事前練習**: どのノブ位置でどんな音か把握しておく

チェケラッチョ！！楽しんでにょん！
