# Claude Code Setup for PicoRuby ESP32

シンプルなClaude Code設定（2025年10月最新ベストプラクティス対応）

## 📁 ファイル構成

```
プロジェクトルート/
├── CLAUDE.md              # メイン設定
├── README.md              # このファイル
└── .claude/
    ├── hardware/
    │   └── SKILL.md       # ハードウェア情報（自動ロード）
    └── picoruby/
        └── SKILL.md       # PicoRuby開発情報（自動ロード）
```

**合計4ファイル**。シンプル！

## 🚀 使い方

### 1. プロジェクトに配置

```bash
cp CLAUDE.md /path/to/your/project/
cp -r .claude /path/to/your/project/
```

### 2. Claude Code起動

```bash
cd /path/to/your/project
claude
```

### 3. 開発開始

Claude Codeで普通に会話するだけ！

**例**:
```
You: GPIOピン配置を教えて
Claude: [ハードウェア情報を自動ロード] → GPIO情報を説明

You: メモリ最適化のベストプラクティスは？
Claude: [PicoRuby情報を自動ロード] → 最適化方法を説明

You: シェイク検知機能を実装して
Claude: [両方の情報を自動ロード] → コード実装
```

## ✨ 特徴

### Agent Skills（自動ロード）

**覚える必要なし！** 必要な時だけ自動で詳細情報をロード：

- **ハードウェア質問** → GPIO、LED、センサー情報を自動参照
- **Ruby質問** → PicoRuby制約、メモリ最適化を自動参照

**トークン効率**: 使わない情報はロードされないので無駄なし！

### Extended Thinking

複雑な実装の場合：
```
You: Think hard about the best approach for motion detection with minimal memory
Claude: [詳細に検討] → 最適な方法を提案
```

`think`, `think hard`, `think harder`, `ultrathink` で推論レベル調整。

## 🔧 開発ワークフロー

### 新機能開発

1. **要件を説明**
   ```
   シェイク検知してLEDを光らせたい
   ```

2. **計画を確認**（複雑な場合）
   ```
   Think hard about the implementation plan
   ```

3. **実装**
   - Claudeが小さく段階的にコード生成
   - `rake build`で動作確認
   - 自動コミット

### コンテキスト管理

新しい機能の度にフレッシュスタート：
```
/clear
新しいタスクについて話す
```

## 📋 よくある質問

**Q: カスタムコマンドは？**
A: なし！シンプルに会話するだけ。

**Q: スキルをいつ使う？**
A: 自動。ハードウェアやRubyの話をすれば自動ロード。

**Q: 設定ファイルの更新は？**
A: CLAUDE.mdだけ編集。スキルは滅多に変更不要。

**Q: トークン使いすぎない？**
A: 大丈夫！必要な情報だけロードされる（Progressive Disclosure）。

**Q: 複数プロジェクトで使える？**
A: はい。各プロジェクトに同じファイルをコピー。

## 🎯 ベストプラクティス

### DO ✅
- 複雑な問題は `think hard` を使う
- 小さく段階的に実装
- `/clear` で新機能ごとにリセット

### DON'T ❌
- 一度に大量の変更を依頼
- 長時間同じ会話を続ける
- カスタムコマンドを覚えようとする（ない！）

## 🔄 アップデート

このシンプル構成は2025年10月のClaude Code v2.0+ベストプラクティスに基づいています：
- Agent Skills（Progressive Disclosure）
- Extended Thinking
- コンテキスト最適化

## 💡 ヒント

- **`rake -T`**: 利用可能なタスク一覧
- **`rake check_env`**: 環境確認
- **ハードウェア質問**: GPIOや仕様を気軽に聞く
- **Ruby質問**: PicoRuby制約やパターンを聞く

---

**シンプルイズベスト！** これだけで十分ピョン！チェケラッチョ！！
