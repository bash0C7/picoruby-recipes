# PicoRuby ESP32 マルチバージョン管理ビルドシステム仕様書

## 概要

ESP32 + PicoRuby開発において、R2P2-ESP32とそのネストされたsubmodule（picoruby-esp32 → picoruby）の複数バージョンを並行管理し、簡単に切り替えながら検証できるビルドシステム。

---

## 設計原則

### 1. Immutableキャッシュ
- `.cache/`に保存されたリポジトリは**絶対に変更しない**
- コミット番号+タイムスタンプで一意に識別
- バージョン変更時は常に新しいキャッシュを作成
- 古いキャッシュは不要になったら`rake cache:prune`で削除

### 2. 環境の独立性
- `build/{env-hash}/`は各環境の完全な作業ディレクトリ
- 複数環境を同時に保持できる
- `build/current`はsymlinkで現在の作業環境を指す

### 3. パッチの永続化
- `patch/`ディレクトリでR2P2-ESP32等への変更をGit管理
- `build/`での変更を`patch/`に書き戻し可能
- 環境切替時に自動的にパッチを適用

### 4. タスク移譲
- 新Rakefile.rbは**環境管理とファイル操作**に特化
- ビルドタスク（build/flash/monitor）はR2P2-ESP32のRakefileに移譲
- ESP-IDF環境変数設定は既存Rakefileの機構を流用

---

## ディレクトリ構造

```
プロジェクトルート/
│
├── storage/home/           # 🔴 装置アプリケーションコード
│   │                         # Git管理対象
│   ├── imu.rb
│   ├── led_ext.rb
│   └── ...
│
├── patch/                  # 🔴 パッチファイル群
│   │                         # Git管理対象
│   ├── README.md
│   ├── R2P2-ESP32/          # サブディレクトリ階層を構築
│   │   └── storage/
│   │       └── home/
│   │           └── custom.rb
│   ├── picoruby-esp32/
│   │   └── (変更があれば)
│   └── picoruby/
│       └── (変更があれば)
│
├── .cache/                 # 🔵 Immutableなバージョンキャッシュ
│   │                         # Git管理外（.gitignore対象）
│   ├── R2P2-ESP32/
│   │   ├── f500652-20241105_143022/    # commit-タイムスタンプ形式
│   │   ├── 34a1c23-20241104_120000/
│   │   └── ...
│   ├── picoruby-esp32/
│   │   ├── 6a6da3a-20241105_142015/
│   │   └── ...
│   └── picoruby/
│       ├── e57c370-20241105_141030/
│       └── ...
│
├── build/                  # 🟢 ビルド作業ディレクトリ
│   │                         # Git管理外（.gitignore対象）
│   ├── current -> f500652-20241105_143022_6a6da3a-..._e57c370-.../
│   │              🔗 symlink（環境切替時に張り替え）
│   │
│   └── f500652-20241105_143022_6a6da3a-20241105_142015_e57c370-20241105_141030/
│       │
│       └── R2P2-ESP32/         # ここでビルド実行
│           ├── components/
│           │   ├── picoruby-esp32/
│           │   │   └── picoruby/
│           │   └── main/
│           ├── storage/home/   # アプリコードをコピー
│           ├── Rakefile
│           ├── build/
│           └── ...
│
├── RAKEFILE_SPEC.md        # 🟡 このファイル（仕様書）
├── Rakefile                # 既存Rakefile（後で削除予定）
├── Rakefile.rb             # 🆕 新ビルドシステム
├── .picoruby-env.yml       # 環境設定ファイル
└── .gitignore              # .cache/, build/を追加
```

---

## 命名規則

### commit-hash形式
```
{7桁のコミットハッシュ}-{YYYYMMDD_HHMMSS}

例：
  f500652-20241105_143022
  6a6da3a-20241105_142015
  e57c370-20241105_141030
```

- コミットハッシュ：`git rev-parse --short=7 {ref}`で取得
- タイムスタンプ：`git show -s --format=%ci {commit}`から抽出
- ローカルのタイムゾーンで記録

### env-hash形式
```
{R2P2-hash}_{esp32-hash}_{picoruby-hash}

例：
  f500652-20241105_143022_6a6da3a-20241105_142015_e57c370-20241105_141030
```

- 3つのcommit-hashを`_`で連結
- 左から順に：R2P2-ESP32 → picoruby-esp32 → picoruby

---

## .picoruby-env.yml形式

```yaml
# PicoRuby開発環境設定ファイル
# 各環境はimmutableで、コミット番号+タイムスタンプで一意に識別される

current: stable-2024-11

environments:
  stable-2024-11:
    R2P2-ESP32:
      commit: f500652
      timestamp: "20241105_143022"
    picoruby-esp32:
      commit: 6a6da3a
      timestamp: "20241105_142015"
    picoruby:
      commit: e57c370
      timestamp: "20241105_141030"
    created_at: "2024-11-05 14:30:22"
    notes: "安定版"

  development:
    R2P2-ESP32:
      commit: 34a1c23
      timestamp: "20241104_120000"
    picoruby-esp32:
      commit: f331744
      timestamp: "20241104_115500"
    picoruby:
      commit: df21508
      timestamp: "20241104_115000"
    created_at: "2024-11-04 12:00:00"
    notes: "開発中"
```

**フィールド説明：**
- `current` - 現在の作業環境名（`build/current`のsymlinkが指す）
- `environments` - 環境定義マップ
- 各環境下の`R2P2-ESP32/picoruby-esp32/picoruby` - コミットとタイムスタンプ
- `created_at` - 環境作成日時（参考用）
- `notes` - 環境の説明（自由記述）

---

## Rakeタスク仕様

### 🔍 環境確認タスク

#### `rake -f Rakefile.rb env:show`
**説明**：現在の環境設定を表示

**出力例**：
```
Current environment: stable-2024-11
Symlink: build/current -> build/f500652-20241105_143022_6a6da3a-20241105_142015_e57c370-20241105_141030/

R2P2-ESP32:    f500652 (2024-11-05 14:30:22)
picoruby-esp32: 6a6da3a (2024-11-05 14:21:15)
picoruby:       e57c370 (2024-11-05 14:10:30)
```

---

#### `rake -f Rakefile.rb env:set[env_name]`
**説明**：指定環境に切り替え

**引数**：
- `env_name` - `.picoruby-env.yml`に定義された環境名

**動作**：
1. `.picoruby-env.yml`から環境定義を読込
2. 対応する`build/{env-hash}/`が存在するか確認
3. `build/current`のsymlinkを張り替え
4. `.picoruby-env.yml`の`current`を更新

**例**：
```bash
rake -f Rakefile.rb env:set[development]
# => Switching to development
#    build/current -> build/34a1c23-20241104_120000_f331744-20241104_115500_df21508-20241104_115000/
```

---

#### `rake -f Rakefile.rb env:latest`
**説明**：最新版を取得して切り替え

**動作**：
1. GitHub API or `git ls-remote`で各repoのHEAD commits取得
2. 新しい環境名を生成（例：`latest-20241105-143500`）
3. `rake cache:fetch`で.cacheに保存
4. `rake build:setup`で環境構築
5. `rake env:set`で切り替え

---

### 📦 キャッシュ管理タスク

#### `rake -f Rakefile.rb cache:list`
**説明**：キャッシュ済みリポジトリ版一覧を表示

**出力例**：
```
=== R2P2-ESP32 ===
  f500652 - 2024-11-05 14:30:22
  34a1c23 - 2024-11-04 12:00:00

=== picoruby-esp32 ===
  6a6da3a - 2024-11-05 14:21:15
  f331744 - 2024-11-04 11:55:00

=== picoruby ===
  e57c370 - 2024-11-05 14:10:30
  df21508 - 2024-11-04 11:50:00

Total cache size: 1.2GB
```

---

#### `rake -f Rakefile.rb cache:fetch[env_name]`
**説明**：指定環境をGitHubから取得して.cacheに保存

**引数**：
- `env_name` - 環境名（`latest`, `feature-xyz`など）
- デフォルト：`latest`

**動作**：
1. `.picoruby-env.yml`から対応する環境定義を読込
2. R2P2-ESP32をclone（`.cache/R2P2-ESP32/{commit-hash}/`）
3. **submodule 3段階トラバース**：
   - Level 1: `components/picoruby-esp32`をupdateする
   - Level 2: `components/picoruby-esp32/picoruby`をupdateする
   - Level 3以降: 警告を出力して処理しない
4. picoruby-esp32とpicorubyもそれぞれ`.cache/`に保存
5. `git show -s --format=%ci`からタイムスタンプを取得
6. `.picoruby-env.yml`に追記

**Submodule 3段階トラバース**：
- Level 1 (R2P2-ESP32)：
  ```ruby
  Dir.chdir('.cache/R2P2-ESP32/{commit-hash}') do
    system('git submodule update --init --recursive')
  end
  ```
- Level 2 (picoruby-esp32)：
  ```ruby
  Dir.chdir('.cache/R2P2-ESP32/{commit-hash}/components/picoruby-esp32') do
    system('git submodule update --init --recursive')
  end
  ```
- Level 3 (picoruby)：
  ```ruby
  Dir.chdir('.cache/R2P2-ESP32/{commit-hash}/components/picoruby-esp32/picoruby') do
    # 4段階目のsubmoduleをチェック
    if system('git config --file .gitmodules --get-regexp path')
      puts "WARNING: Found 4th-level submodule(s) - not handled"
    end
  end
  ```

**例**：
```bash
rake -f Rakefile.rb cache:fetch[latest]
# => Fetching R2P2-ESP32 HEAD...
#    Cloning to .cache/R2P2-ESP32/34a1c23-20241104_120000/
#    Updating submodule: components/picoruby-esp32
#    Updating submodule: components/picoruby-esp32/picoruby
#    Updating .picoruby-env.yml...
#    Done!
```

---

#### `rake -f Rakefile.rb cache:clean[repo]`
**説明**：指定repoのキャッシュ全削除

**引数**：
- `repo` - `R2P2-ESP32`, `picoruby-esp32`, `picoruby` のいずれか

**動作**：
1. `.cache/{repo}/`配下の全ディレクトリを削除
2. `.picoruby-env.yml`から該当commitを削除

**例**：
```bash
rake -f Rakefile.rb cache:clean[picoruby-esp32]
# => Removing .cache/picoruby-esp32/...
```

---

#### `rake -f Rakefile.rb cache:prune`
**説明**：どの環境からも参照されていないキャッシュを削除

**動作**：
1. `.picoruby-env.yml`の全環境から使用中のcommitを収集
2. `.cache/`にあるすべてのcommitと照合
3. 未使用のcommitを削除

**例**：
```bash
rake -f Rakefile.rb cache:prune
# => Unused .cache/R2P2-ESP32/old-hash-20240101_000000/ - removing
#    Freed: 500MB
```

---

### 🔨 ビルド環境構築タスク

#### `rake -f Rakefile.rb build:setup[env_name]`
**説明**：指定環境で`build/{env-hash}/`を構築

**引数**：
- `env_name` - 環境名（デフォルト：`current`）

**動作**：
1. `.picoruby-env.yml`から環境定義を読込
2. 対応するキャッシュが`.cache/`に存在するか確認（なければエラー）
3. `build/{env-hash}/`ディレクトリを作成
4. `.cache/R2P2-ESP32/{commit-hash}/`から`build/{env-hash}/R2P2-ESP32/`へコピー
5. `build/{env-hash}/R2P2-ESP32/components/picoruby-esp32/`を削除
6. `.cache/picoruby-esp32/{commit-hash}/`から`build/{env-hash}/R2P2-ESP32/components/picoruby-esp32/`へコピー
7. 同様に`picoruby/`をコピー
8. `patch/`を適用（`patch:apply`と同じ処理）
9. `storage/home/`を`build/{env-hash}/R2P2-ESP32/storage/home/`にコピー
10. `build/current`のsymlinkを`build/{env-hash}/`に張替

**例**：
```bash
rake -f Rakefile.rb build:setup[stable-2024-11]
# => Setting up build environment: stable-2024-11
#    Creating build/f500652-20241105_143022_6a6da3a-20241105_142015_e57c370-20241105_141030/
#    Copying .cache/R2P2-ESP32/f500652-20241105_143022/
#    Copying .cache/picoruby-esp32/6a6da3a-20241105_142015/
#    Copying .cache/picoruby/e57c370-20241105_141030/
#    Applying patches...
#    Copying storage/home/
#    Updating symlink: build/current
#    Done! (Ready to build)
```

---

#### `rake -f Rakefile.rb build:clean[env_name]`
**説明**：指定ビルド環境を削除

**引数**：
- `env_name` - 環境名（デフォルト：`current`）

**動作**：
1. `build/current`がsymlinkの場合、その先を読み取り
2. env_nameが`current`の場合は、symlink先を削除して`build/current`をクリア
3. それ以外は指定環境を削除

**例**：
```bash
rake -f Rakefile.rb build:clean[development]
# => Removing build/34a1c23-20241104_120000_f331744-20241104_115500_df21508-20241104_115000/
```

---

#### `rake -f Rakefile.rb build:list`
**説明**：`build/`配下の構築済み環境一覧を表示

**出力例**：
```
=== Build Environments ===

build/current -> f500652-20241105_143022_6a6da3a-20241105_142015_e57c370-20241105_141030/

Available:
  f500652-20241105_143022_6a6da3a-20241105_142015_e57c370-20241105_141030/    (2.5GB)  stable-2024-11
  34a1c23-20241104_120000_f331744-20241104_115500_df21508-20241104_115000/    (2.3GB)  development

Total build storage: 4.8GB
```

---

### 🔀 パッチ管理タスク

#### `rake -f Rakefile.rb patch:export[env_name]`
**説明**：`build/{env}/`の変更を`patch/`に書き戻し

**引数**：
- `env_name` - 環境名（デフォルト：`current`）

**動作**：
1. `build/{env}/R2P2-ESP32/`で`git diff --name-only`を実行
2. 各ファイルについて：
   - ディレクトリ構造を`patch/R2P2-ESP32/`に再現
   - `git show HEAD:{file}`と`build/{env}/{file}`の差分を`patch/`に保存
3. `components/picoruby-esp32/`と`picoruby/`についても同様

**例**：
```bash
# build/current/R2P2-ESP32/storage/home/custom.rb を編集した場合

rake -f Rakefile.rb patch:export
# => Exporting changes from build/current/
#    patch/R2P2-ESP32/storage/home/custom.rb (created)
#    patch/picoruby-esp32/ (no changes)
#    patch/picoruby/ (no changes)
#    Done!
```

---

#### `rake -f Rakefile.rb patch:apply[env_name]`
**説明**：`patch/`を`build/{env}/`に適用

**引数**：
- `env_name` - 環境名（デフォルト：`current`）

**動作**：
1. `patch/R2P2-ESP32/`配下のすべてのファイルを読込
2. 対応するパスに`build/{env}/R2P2-ESP32/`へコピー
3. ディレクトリ構造が異なれば作成
4. `components/picoruby-esp32/`と`picoruby/`についても同様

---

#### `rake -f Rakefile.rb patch:diff[env_name]`
**説明**：`build/{env}/`での現在の変更と既存パッチの差分を表示

**引数**：
- `env_name` - 環境名（デフォルト：`current`）

**出力例**：
```
=== R2P2-ESP32 ===
diff --git a/storage/home/custom.rb (working) vs (patch/)
+ (新規追加)
- (削除予定)
  (変更内容を表示)

=== picoruby-esp32 ===
(no changes)
```

---

### 🚀 R2P2-ESP32タスク透過移譲

#### `rake -f Rakefile.rb build[env_name]`
**説明**：R2P2-ESP32をビルド

**引数**：
- `env_name` - 環境名（デフォルト：`current`）

**動作**：
1. `build/{env}/R2P2-ESP32/`にcdする
2. ESP-IDF環境変数を設定（既存Rakefileの`setup_environment`を流用）
3. R2P2-ESP32の`Rakefile`で`rake build`を実行

**例**：
```bash
rake -f Rakefile.rb build[stable-2024-11]
# => Building in build/f500652-.../R2P2-ESP32/
#    [idf.py build output...]
```

---

#### `rake -f Rakefile.rb flash[env_name]`
**説明**：ビルドしたファームウェアをESP32に書き込み

**引数**：
- `env_name` - 環境名（デフォルト：`current`）

**動作**：
1. `build/{env}/R2P2-ESP32/`にcdする
2. ESP-IDF環境変数を設定
3. R2P2-ESP32の`Rakefile`で`rake flash`を実行

---

#### `rake -f Rakefile.rb monitor[env_name]`
**説明**：ESP32のシリアル出力をモニター

**引数**：
- `env_name` - 環境名（デフォルト：`current`）

**動作**：
1. `build/{env}/R2P2-ESP32/`にcdする
2. ESP-IDF環境変数を設定
3. R2P2-ESP32の`Rakefile`で`rake monitor`を実行

---

## 実装ワークフロー例

### シナリオ1: 安定版でビルド・実行

```bash
# 1. 環境確認
rake -f Rakefile.rb env:show

# 2. ビルド・フラッシュ・モニター
rake -f Rakefile.rb build
rake -f Rakefile.rb flash
rake -f Rakefile.rb monitor

# Ctrl+C で終了
```

### シナリオ2: 最新版を検証

```bash
# 1. 最新版取得
rake -f Rakefile.rb env:latest
# => Fetching latest from GitHub...
#    Created environment: latest-20241105-143500
#    setup環境構築...
#    Switched to: latest-20241105-143500

# 2. ビルド
rake -f Rakefile.rb build

# 3. 問題があれば、安定版に戻す
rake -f Rakefile.rb env:set[stable-2024-11]
rake -f Rakefile.rb build
```

### シナリオ3: パッチの管理

```bash
# 1. build/current/ で変更を加える
# （ファイル編集）

# 2. 変更をパッチに書き戻す
rake -f Rakefile.rb patch:export

# 3. Gitコミット
git add patch/ storage/home/
git commit -m "Update patches and storage"

# 4. 別環境で適用テスト
rake -f Rakefile.rb env:set[development]
rake -f Rakefile.rb build:setup  # パッチ自動適用
rake -f Rakefile.rb build
```

---

## 注意事項

### パッチ適用のルール
- `patch/`配下のファイルは、変更がある場合のみ配置
- ディレクトリは変更がないと作成しない（空ディレクトリなし）
- `storage/home/`はパッチではなく、Git管理される実装コード

### キャッシュの永続性
- `.cache/`は削除しない限り**永遠に保持される**
- ディスク容量に注意（`rake cache:prune`で不要な古いバージョンを削除）
- CI/CDでキャッシュを共有したい場合は、`.cache/`全体をアーティファクトに

### submodule 4段階目以降
- 3段階目（picoruby）のさらに先にsubmoduleがある場合、WARNING出力
- 4段階目以降は**手動でハンドリング**（スコープ外）

---

## トラブルシューティング

### キャッシュが取得できない
```bash
# GitHub接続確認
git ls-remote https://github.com/picoruby/R2P2-ESP32.git HEAD

# キャッシュを削除して再取得
rake -f Rakefile.rb cache:clean[R2P2-ESP32]
rake -f Rakefile.rb cache:fetch[latest]
```

### ビルド環境がない
```bash
# キャッシュ確認
rake -f Rakefile.rb cache:list

# 環境構築
rake -f Rakefile.rb build:setup[env_name]
```

### パッチが適用されていない
```bash
# 差分確認
rake -f Rakefile.rb patch:diff

# 再適用
rake -f Rakefile.rb build:clean
rake -f Rakefile.rb build:setup[env_name]
```

---

## 今後の拡張

- [ ] キャッシュの自動圧縮（tar.gz化）
- [ ] S3/Cloudストレージへのバックアップ
- [ ] CI/CDでのキャッシュ自動取得
- [ ] GUIでの環境管理ツール
- [ ] バージョン比較ツール

---

## 変更履歴

| 日時 | 版 | 変更内容 |
|-----|---|--------|
| 2024-11-05 | 1.0 | 初版作成 |

