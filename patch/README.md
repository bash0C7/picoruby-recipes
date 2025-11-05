# パッチ管理ディレクトリ

R2P2-ESP32とそのネストされたsubmodule（picoruby-esp32/picoruby）への変更をGit管理するためのディレクトリです。

## ディレクトリ構造

```
patch/
├── R2P2-ESP32/
│   └── (変更がある場合のみディレクトリを作成)
├── picoruby-esp32/
│   └── (変更がある場合のみディレクトリを作成)
└── picoruby/
    └── (変更がある場合のみディレクトリを作成)
```

## 使い方

### 1. `build/current/` で変更を加える

任意のファイルを編集します：

```bash
# 例：カスタムコードを追加
vim build/current/R2P2-ESP32/storage/home/custom.rb
```

### 2. パッチに書き戻す

```bash
rake -f Rakefile.rb patch:export
# => patch/R2P2-ESP32/storage/home/custom.rb が作成される
```

### 3. Git管理する

```bash
git add patch/ storage/home/
git commit -m "Update patches and application code"
```

### 4. 別の環境で パッチを適用

```bash
rake -f Rakefile.rb env:set[development]
rake -f Rakefile.rb build:setup
# => patch/ が自動的に適用される
rake -f Rakefile.rb build
```

## 注意点

- **空ディレクトリは作成しない**
  - 変更があるファイルが属するディレクトリのみ階層を再現します

- **storage/home/ との役割分担**
  - `storage/home/` - 装置アプリケーションコード（直接Git管理）
  - `patch/` - R2P2-ESP32/picoruby-esp32/picoruby への変更（patches）

- **パッチの同期**
  - `build/current/` での変更は `patch:export` で `patch/` に反映
  - 新しい環境で `build:setup` すると自動的に `patch/` が適用されます

## トラブルシューティング

### パッチが正しく適用されない場合

```bash
# 差分を確認
rake -f Rakefile.rb patch:diff

# ビルド環境を再構築
rake -f Rakefile.rb build:clean
rake -f Rakefile.rb build:setup[env_name]
```

## 参考

詳細な仕様は [RAKEFILE_SPEC.md](../RAKEFILE_SPEC.md) を参照してください。
