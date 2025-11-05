#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'yaml'
require 'time'
require 'shellwords'

# PicoRuby マルチバージョン管理ビルドシステム
# See RAKEFILE_SPEC.md for detailed specifications

module PicoRubyEnv
  # ルートディレクトリ
  PROJECT_ROOT = Dir.pwd
  CACHE_DIR = File.join(PROJECT_ROOT, '.cache')
  BUILD_DIR = File.join(PROJECT_ROOT, 'build')
  PATCH_DIR = File.join(PROJECT_ROOT, 'patch')
  STORAGE_HOME = File.join(PROJECT_ROOT, 'storage', 'home')
  ENV_FILE = File.join(PROJECT_ROOT, '.picoruby-env.yml')

  # リポジトリ定義
  REPOS = {
    'R2P2-ESP32' => 'https://github.com/picoruby/R2P2-ESP32.git',
    'picoruby-esp32' => 'https://github.com/picoruby/picoruby-esp32.git',
    'picoruby' => 'https://github.com/picoruby/picoruby.git'
  }

  # Submodule パス（3段階）
  SUBMODULE_PATHS = {
    'R2P2-ESP32' => 'components/picoruby-esp32',
    'picoruby-esp32' => 'picoruby'
  }

  class << self
    # ====== YAML操作 ======

    # .picoruby-env.yml を読み込み
    def load_env_file
      return {} unless File.exist?(ENV_FILE)
      YAML.load_file(ENV_FILE) || {}
    end

    # .picoruby-env.yml に保存
    def save_env_file(data)
      FileUtils.mkdir_p(File.dirname(ENV_FILE))
      File.write(ENV_FILE, YAML.dump(data))
    end

    # 環境定義を読み込み
    def get_environment(env_name)
      data = load_env_file
      environments = data['environments'] || {}
      environments[env_name]
    end

    # 環境定義を追加/更新
    def set_environment(env_name, r2p2_info, esp32_info, picoruby_info, notes: '')
      data = load_env_file
      data['environments'] ||= {}

      data['environments'][env_name] = {
        'R2P2-ESP32' => r2p2_info,
        'picoruby-esp32' => esp32_info,
        'picoruby' => picoruby_info,
        'created_at' => Time.now.to_s,
        'notes' => notes
      }

      save_env_file(data)
    end

    # 現在の環境名を取得
    def get_current_env
      data = load_env_file
      data['current']
    end

    # 現在の環境名を設定
    def set_current_env(env_name)
      data = load_env_file
      data['current'] = env_name
      save_env_file(data)
    end

    # ====== Git操作 ======

    # リモートからコミット情報を取得（git ls-remote使用）
    def fetch_remote_commit(repo_url, ref = 'HEAD')
      output = `git ls-remote #{Shellwords.escape(repo_url)} #{Shellwords.escape(ref)} 2>/dev/null`
      return nil if output.empty?
      output.split.first[0..6]  # 7桁のコミットハッシュ
    end

    # リポジトリをクローン
    def clone_repo(repo_url, dest_path, commit)
      return if Dir.exist?(dest_path)

      puts "Cloning #{repo_url} to #{dest_path}..."
      unless system("git clone #{Shellwords.escape(repo_url)} #{Shellwords.escape(dest_path)}")
        raise "Failed to clone repository"
      end

      # 指定コミットにチェックアウト
      Dir.chdir(dest_path) do
        unless system("git checkout #{Shellwords.escape(commit)}")
          raise "Failed to checkout commit #{commit}"
        end
      end
    end

    # リポジトリをクローン＆submodule初期化
    def clone_with_submodules(repo_url, dest_path, commit)
      clone_repo(repo_url, dest_path, commit)

      Dir.chdir(dest_path) do
        # Submodule初期化
        unless system('git submodule update --init --recursive')
          raise "Failed to initialize submodules"
        end
      end
    end

    # コミット情報からcommit-hash形式を生成
    def get_commit_hash(repo_path, commit)
      Dir.chdir(repo_path) do
        short_hash = `git rev-parse --short=7 #{Shellwords.escape(commit)}`.strip
        timestamp_str = `git show -s --format=%ci #{Shellwords.escape(commit)}`.strip
        timestamp = Time.parse(timestamp_str).strftime('%Y%m%d_%H%M%S')
        "#{short_hash}-#{timestamp}"
      end
    end

    # Submodule 3段階トラバース
    def traverse_submodules_and_validate(repo_path)
      info = {}
      warnings = []

      # R2P2-ESP32の情報取得
      r2p2_short = `git -C #{Shellwords.escape(repo_path)} rev-parse --short=7 HEAD`.strip
      r2p2_timestamp = get_timestamp(repo_path)
      info['R2P2-ESP32'] = "#{r2p2_short}-#{r2p2_timestamp}"

      # Level 1: components/picoruby-esp32
      esp32_path = File.join(repo_path, 'components', 'picoruby-esp32')
      if Dir.exist?(esp32_path)
        esp32_short = `git -C #{Shellwords.escape(esp32_path)} rev-parse --short=7 HEAD`.strip
        esp32_timestamp = get_timestamp(esp32_path)
        info['picoruby-esp32'] = "#{esp32_short}-#{esp32_timestamp}"

        # Level 2: picoruby-esp32/picoruby
        picoruby_path = File.join(esp32_path, 'picoruby')
        if Dir.exist?(picoruby_path)
          picoruby_short = `git -C #{Shellwords.escape(picoruby_path)} rev-parse --short=7 HEAD`.strip
          picoruby_timestamp = get_timestamp(picoruby_path)
          info['picoruby'] = "#{picoruby_short}-#{picoruby_timestamp}"

          # Level 3以降: warning
          if has_submodules?(picoruby_path)
            warnings << "WARNING: Found submodule(s) in picoruby (4th level and beyond) - not handled by this tool"
          end
        end
      end

      [info, warnings]
    end

    # ====== ユーティリティ ======

    # Timestamp取得（ローカルタイムゾーン）
    def get_timestamp(repo_path)
      timestamp_str = `git -C #{Shellwords.escape(repo_path)} show -s --format=%ci HEAD`.strip
      Time.parse(timestamp_str).strftime('%Y%m%d_%H%M%S')
    end

    # Submoduleの存在確認
    def has_submodules?(repo_path)
      gitmodules_path = File.join(repo_path, '.gitmodules')
      File.exist?(gitmodules_path)
    end

    # env-hash形式を生成
    def generate_env_hash(r2p2_info, esp32_info, picoruby_info)
      "#{r2p2_info}_#{esp32_info}_#{picoruby_info}"
    end

    # キャッシュディレクトリを取得
    def get_cache_path(repo_name, commit_hash)
      File.join(CACHE_DIR, repo_name, commit_hash)
    end

    # ビルドディレクトリを取得
    def get_build_path(env_hash)
      File.join(BUILD_DIR, env_hash)
    end

    # Symlink操作
    def create_symlink(target, link)
      FileUtils.rm_f(link) if File.exist?(link) || File.symlink?(link)
      FileUtils.ln_s(target, link)
    end

    # Symlink先を取得
    def read_symlink(link)
      return nil unless File.symlink?(link)
      File.readlink(link)
    end

    # ESP-IDF環境変数設定
    def setup_esp_idf_env
      homebrew_openssl = '/opt/homebrew/opt/openssl'
      esp_idf_path = ENV['IDF_PATH'] || "#{ENV['HOME']}/esp/esp-idf"

      env_vars = {
        'PATH' => "#{homebrew_openssl}/bin:#{ENV['PATH']}",
        'LDFLAGS' => "-L#{homebrew_openssl}/lib #{ENV['LDFLAGS']}",
        'CPPFLAGS' => "-I#{homebrew_openssl}/include #{ENV['CPPFLAGS']}",
        'CFLAGS' => "-I#{homebrew_openssl}/include #{ENV['CFLAGS']}",
        'PKG_CONFIG_PATH' => "#{homebrew_openssl}/lib/pkgconfig:#{ENV['PKG_CONFIG_PATH']}",
        'GRPC_PYTHON_BUILD_SYSTEM_OPENSSL' => '1',
        'GRPC_PYTHON_BUILD_SYSTEM_ZLIB' => '1',
        'ESPBAUD' => '115200',
        'IDF_PATH' => esp_idf_path
      }

      env_vars.each { |key, value| ENV[key] = value }
    end

    # ESP-IDF環境でコマンド実行
    def execute_with_esp_env(command, working_dir = nil)
      esp_idf_path = ENV['IDF_PATH'] || "#{ENV['HOME']}/esp/esp-idf"

      setup_script = <<~SCRIPT
        export PATH="/opt/homebrew/opt/openssl/bin:$PATH"
        export LDFLAGS="-L/opt/homebrew/opt/openssl/lib $LDFLAGS"
        export CPPFLAGS="-I/opt/homebrew/opt/openssl/include $CPPFLAGS"
        export CFLAGS="-I/opt/homebrew/opt/openssl/include $CFLAGS"
        export PKG_CONFIG_PATH="/opt/homebrew/opt/openssl/lib/pkgconfig:$PKG_CONFIG_PATH"
        export GRPC_PYTHON_BUILD_SYSTEM_OPENSSL=1
        export GRPC_PYTHON_BUILD_SYSTEM_ZLIB=1
        export ESPBAUD=115200
        . #{Shellwords.escape(esp_idf_path)}/export.sh
        #{command}
      SCRIPT

      if working_dir
        Dir.chdir(working_dir) do
          success = system('bash', '-c', setup_script)
          raise "Command failed: #{command}" unless success
        end
      else
        success = system('bash', '-c', setup_script)
        raise "Command failed: #{command}" unless success
      end
    end
  end
end

# ====== Rakeタスク定義 ======

namespace :env do
  desc '現在の環境設定を表示'
  task :show do
    current = PicoRubyEnv.get_current_env
    if current.nil?
      puts "Current environment: (not set)"
      puts "Run 'rake env:set[env_name]' to set an environment"
    else
      env_config = PicoRubyEnv.get_environment(current)
      if env_config.nil?
        puts "Error: Environment '#{current}' not found in .picoruby-env.yml"
      else
        puts "Current environment: #{current}"

        # Symlink情報
        current_link = File.join(PicoRubyEnv::BUILD_DIR, 'current')
        if File.symlink?(current_link)
          target = File.readlink(current_link)
          puts "Symlink: #{File.basename(current_link)} -> #{File.basename(target)}/"
        end

        puts "\nRepo versions:"
        %w[R2P2-ESP32 picoruby-esp32 picoruby].each do |repo|
          info = env_config[repo] || {}
          commit = info['commit'] || 'N/A'
          timestamp = info['timestamp'] || 'N/A'
          puts "  #{repo}: #{commit} (#{timestamp})"
        end

        puts "\nCreated: #{env_config['created_at']}"
        puts "Notes: #{env_config['notes']}" unless env_config['notes'].empty?
      end
    end
  end

  desc '環境を切り替え: rake env:set[env_name]'
  task :set, [:env_name] do |_t, args|
    env_name = args[:env_name]
    raise "Error: env_name is required" if env_name.nil?

    env_config = PicoRubyEnv.get_environment(env_name)
    raise "Error: Environment '#{env_name}' not found" if env_config.nil?

    # ビルド環境が存在するか確認
    r2p2_hash = env_config['R2P2-ESP32']['commit'] + '-' + env_config['R2P2-ESP32']['timestamp']
    esp32_hash = env_config['picoruby-esp32']['commit'] + '-' + env_config['picoruby-esp32']['timestamp']
    picoruby_hash = env_config['picoruby']['commit'] + '-' + env_config['picoruby']['timestamp']
    env_hash = PicoRubyEnv.generate_env_hash(r2p2_hash, esp32_hash, picoruby_hash)
    build_path = PicoRubyEnv.get_build_path(env_hash)

    if Dir.exist?(build_path)
      puts "Switching to environment: #{env_name}"
      current_link = File.join(PicoRubyEnv::BUILD_DIR, 'current')
      PicoRubyEnv.create_symlink(File.basename(build_path), current_link)
      PicoRubyEnv.set_current_env(env_name)
      puts "✓ Switched to #{env_name}"
    else
      puts "Error: Build environment not found at #{build_path}"
      puts "Run 'rake build:setup[#{env_name}]' first"
    end
  end

  desc '最新版を取得して切り替え'
  task :latest do
    puts "Fetching latest commits from GitHub..."
    raise "Not yet implemented - use cache:fetch[env_name] instead"
  end
end

namespace :cache do
  desc 'キャッシュ済みリポジトリ一覧を表示'
  task :list do
    puts "=== Cached Repositories ===\n"

    %w[R2P2-ESP32 picoruby-esp32 picoruby].each do |repo|
      repo_cache = File.join(PicoRubyEnv::CACHE_DIR, repo)
      if Dir.exist?(repo_cache)
        puts "#{repo}:"
        Dir.entries(repo_cache).sort.reverse.each do |entry|
          next if ['.', '..'].include?(entry)
          puts "  #{entry}"
        end
      else
        puts "#{repo}: (no cache)"
      end
      puts
    end
  end

  desc '指定環境をGitHubから.cacheに取得: rake cache:fetch[env_name]'
  task :fetch, [:env_name] do |_t, args|
    env_name = args[:env_name] || 'latest'
    puts "Fetching environment: #{env_name}"

    # 環境定義を読込
    env_config = PicoRubyEnv.get_environment(env_name)
    raise "Error: Environment '#{env_name}' not found" if env_config.nil?

    # キャッシュディレクトリを作成
    FileUtils.mkdir_p(PicoRubyEnv::CACHE_DIR)

    # 各リポジトリをキャッシュに保存
    repos_to_fetch = [
      { repo: 'R2P2-ESP32', url: PicoRubyEnv::REPOS['R2P2-ESP32'], commit: env_config['R2P2-ESP32']['commit'] },
      { repo: 'picoruby-esp32', url: PicoRubyEnv::REPOS['picoruby-esp32'], commit: env_config['picoruby-esp32']['commit'] },
      { repo: 'picoruby', url: PicoRubyEnv::REPOS['picoruby'], commit: env_config['picoruby']['commit'] }
    ]

    repos_to_fetch.each do |repo_info|
      repo_name = repo_info[:repo]
      cache_hash = repo_info[:commit] + '-' + env_config[repo_name]['timestamp']
      cache_path = PicoRubyEnv.get_cache_path(repo_name, cache_hash)

      if Dir.exist?(cache_path)
        puts "  ✓ #{repo_name} already cached"
      else
        puts "  Fetching #{repo_name}..."
        PicoRubyEnv.clone_with_submodules(repo_info[:url], cache_path, repo_info[:commit])
        puts "  ✓ #{repo_name} cached to #{cache_path}"
      end
    end

    # R2P2-ESP32からsubmodule情報を取得して検証
    r2p2_cache = PicoRubyEnv.get_cache_path('R2P2-ESP32',
      env_config['R2P2-ESP32']['commit'] + '-' + env_config['R2P2-ESP32']['timestamp'])

    _info, warnings = PicoRubyEnv.traverse_submodules_and_validate(r2p2_cache)
    warnings.each { |w| puts "⚠️  #{w}" }

    puts "✓ Environment '#{env_name}' fetched successfully"
  end

  desc 'キャッシュを削除: rake cache:clean[repo]'
  task :clean, [:repo] do |_t, args|
    repo = args[:repo]
    raise "Error: repo is required" if repo.nil?

    cache_path = File.join(PicoRubyEnv::CACHE_DIR, repo)
    if Dir.exist?(cache_path)
      puts "Removing cache: #{cache_path}"
      FileUtils.rm_rf(cache_path)
      puts "✓ Cache cleaned"
    else
      puts "Cache not found: #{cache_path}"
    end
  end

  desc '未使用キャッシュを削除'
  task :prune do
    puts "Pruning unused cache..."
    data = PicoRubyEnv.load_env_file
    used_commits = Set.new

    # 使用中のコミットを収集
    (data['environments'] || {}).each do |_env_name, env_config|
      %w[R2P2-ESP32 picoruby-esp32 picoruby].each do |repo|
        info = env_config[repo]
        next if info.nil?
        used_commits << (info['commit'] + '-' + info['timestamp'])
      end
    end

    # キャッシュディレクトリをスキャン
    %w[R2P2-ESP32 picoruby-esp32 picoruby].each do |repo|
      repo_cache_dir = File.join(PicoRubyEnv::CACHE_DIR, repo)
      next unless Dir.exist?(repo_cache_dir)

      Dir.entries(repo_cache_dir).each do |entry|
        next if ['.', '..'].include?(entry)

        if used_commits.include?(entry)
          puts "  Keep: #{repo}/#{entry}"
        else
          cache_path = File.join(repo_cache_dir, entry)
          puts "  Remove: #{repo}/#{entry}"
          FileUtils.rm_rf(cache_path)
        end
      end
    end

    puts "✓ Pruning completed"
  end
end

namespace :build do
  desc 'ビルド環境を構築: rake build:setup[env_name]'
  task :setup, [:env_name] do |_t, args|
    env_name = args[:env_name] || 'current'

    # currentの場合はsymlinkから実環境名を取得
    if env_name == 'current'
      current_link = File.join(PicoRubyEnv::BUILD_DIR, 'current')
      if File.symlink?(current_link)
        current = PicoRubyEnv.get_current_env
        env_name = current if current
      else
        raise "Error: No current environment set. Use 'rake env:set[env_name]' first"
      end
    end

    env_config = PicoRubyEnv.get_environment(env_name)
    raise "Error: Environment '#{env_name}' not found" if env_config.nil?

    # env-hashを生成
    r2p2_hash = env_config['R2P2-ESP32']['commit'] + '-' + env_config['R2P2-ESP32']['timestamp']
    esp32_hash = env_config['picoruby-esp32']['commit'] + '-' + env_config['picoruby-esp32']['timestamp']
    picoruby_hash = env_config['picoruby']['commit'] + '-' + env_config['picoruby']['timestamp']
    env_hash = PicoRubyEnv.generate_env_hash(r2p2_hash, esp32_hash, picoruby_hash)

    build_path = PicoRubyEnv.get_build_path(env_hash)

    # キャッシュが存在するか確認
    r2p2_cache = PicoRubyEnv.get_cache_path('R2P2-ESP32', r2p2_hash)
    esp32_cache = PicoRubyEnv.get_cache_path('picoruby-esp32', esp32_hash)
    picoruby_cache = PicoRubyEnv.get_cache_path('picoruby', picoruby_hash)

    raise "Error: R2P2-ESP32 cache not found. Run 'rake cache:fetch[#{env_name}]' first" unless Dir.exist?(r2p2_cache)
    raise "Error: picoruby-esp32 cache not found. Run 'rake cache:fetch[#{env_name}]' first" unless Dir.exist?(esp32_cache)
    raise "Error: picoruby cache not found. Run 'rake cache:fetch[#{env_name}]' first" unless Dir.exist?(picoruby_cache)

    puts "Setting up build environment: #{env_name}"

    # ビルドディレクトリを作成
    FileUtils.mkdir_p(PicoRubyEnv::BUILD_DIR)

    if Dir.exist?(build_path)
      puts "  ✓ Build environment already exists"
    else
      puts "  Creating build environment at #{build_path}"
      FileUtils.mkdir_p(build_path)

      # キャッシュからコピー
      puts "  Copying R2P2-ESP32..."
      FileUtils.cp_r(r2p2_cache, File.join(build_path, 'R2P2-ESP32'))

      puts "  Copying picoruby-esp32..."
      esp32_dest = File.join(build_path, 'R2P2-ESP32', 'components', 'picoruby-esp32')
      FileUtils.rm_rf(esp32_dest) if Dir.exist?(esp32_dest)
      FileUtils.cp_r(esp32_cache, esp32_dest)

      puts "  Copying picoruby..."
      picoruby_dest = File.join(build_path, 'R2P2-ESP32', 'components', 'picoruby-esp32', 'picoruby')
      FileUtils.rm_rf(picoruby_dest) if Dir.exist?(picoruby_dest)
      FileUtils.cp_r(picoruby_cache, picoruby_dest)

      # パッチを適用
      Rake::Task['patch:apply'].invoke(env_name)

      # storage/homeをコピー
      puts "  Copying storage/home..."
      home_src = File.join(PicoRubyEnv::STORAGE_HOME)
      home_dest = File.join(build_path, 'R2P2-ESP32', 'storage', 'home')
      FileUtils.rm_rf(home_dest) if Dir.exist?(home_dest)
      FileUtils.mkdir_p(File.dirname(home_dest))
      FileUtils.cp_r(home_src, home_dest) if Dir.exist?(home_src)
    end

    # Symlinkを更新
    puts "  Updating symlink: build/current"
    current_link = File.join(PicoRubyEnv::BUILD_DIR, 'current')
    PicoRubyEnv.create_symlink(File.basename(build_path), current_link)
    PicoRubyEnv.set_current_env(env_name)

    puts "✓ Build environment ready for: #{env_name}"
  end

  desc 'ビルド環境を削除: rake build:clean[env_name]'
  task :clean, [:env_name] do |_t, args|
    env_name = args[:env_name] || 'current'

    # currentの場合はsymlinkから実環境を取得
    if env_name == 'current'
      current_link = File.join(PicoRubyEnv::BUILD_DIR, 'current')
      if File.symlink?(current_link)
        target = File.readlink(current_link)
        build_path = File.join(PicoRubyEnv::BUILD_DIR, target)
        FileUtils.rm_rf(build_path) if Dir.exist?(build_path)
        FileUtils.rm_f(current_link)
        PicoRubyEnv.set_current_env(nil)
        puts "✓ Current build environment removed"
      else
        puts "No current environment to clean"
      end
    else
      env_config = PicoRubyEnv.get_environment(env_name)
      raise "Error: Environment '#{env_name}' not found" if env_config.nil?

      r2p2_hash = env_config['R2P2-ESP32']['commit'] + '-' + env_config['R2P2-ESP32']['timestamp']
      esp32_hash = env_config['picoruby-esp32']['commit'] + '-' + env_config['picoruby-esp32']['timestamp']
      picoruby_hash = env_config['picoruby']['commit'] + '-' + env_config['picoruby']['timestamp']
      env_hash = PicoRubyEnv.generate_env_hash(r2p2_hash, esp32_hash, picoruby_hash)
      build_path = PicoRubyEnv.get_build_path(env_hash)

      if Dir.exist?(build_path)
        puts "Removing build environment: #{env_name}"
        FileUtils.rm_rf(build_path)
        puts "✓ Build environment removed"
      else
        puts "Build environment not found: #{env_name}"
      end
    end
  end

  desc 'ビルド環境一覧を表示'
  task :list do
    puts "=== Build Environments ===\n"

    current_link = File.join(PicoRubyEnv::BUILD_DIR, 'current')
    if File.symlink?(current_link)
      target = File.readlink(current_link)
      puts "Current: build/current -> #{target}/\n"
    else
      puts "Current: (not set)\n"
    end

    if Dir.exist?(PicoRubyEnv::BUILD_DIR)
      puts "Available:"
      Dir.entries(PicoRubyEnv::BUILD_DIR).sort.each do |entry|
        next if ['.', '..', 'current'].include?(entry)

        build_path = File.join(PicoRubyEnv::BUILD_DIR, entry)
        next unless File.directory?(build_path)

        size = `du -sh #{Shellwords.escape(build_path)} 2>/dev/null`.split.first || "0"
        puts "  #{entry}  (#{size})"
      end
    else
      puts "No build environments found"
    end
  end
end

namespace :patch do
  desc '変更をパッチに書き戻し: rake patch:export[env_name]'
  task :export, [:env_name] do |_t, args|
    env_name = args[:env_name] || 'current'

    # currentの場合はsymlinkから実環境名を取得
    if env_name == 'current'
      current_link = File.join(PicoRubyEnv::BUILD_DIR, 'current')
      if File.symlink?(current_link)
        current = PicoRubyEnv.get_current_env
        env_name = current if current
      else
        raise "Error: No current environment set"
      end
    end

    env_config = PicoRubyEnv.get_environment(env_name)
    raise "Error: Environment '#{env_name}' not found" if env_config.nil?

    r2p2_hash = env_config['R2P2-ESP32']['commit'] + '-' + env_config['R2P2-ESP32']['timestamp']
    esp32_hash = env_config['picoruby-esp32']['commit'] + '-' + env_config['picoruby-esp32']['timestamp']
    picoruby_hash = env_config['picoruby']['commit'] + '-' + env_config['picoruby']['timestamp']
    env_hash = PicoRubyEnv.generate_env_hash(r2p2_hash, esp32_hash, picoruby_hash)

    build_path = PicoRubyEnv.get_build_path(env_hash)
    raise "Error: Build environment not found: #{env_name}" unless Dir.exist?(build_path)

    puts "Exporting patches from: #{env_name}"

    %w[R2P2-ESP32 picoruby-esp32 picoruby].each do |repo|
      case repo
      when 'R2P2-ESP32'
        work_path = File.join(build_path, 'R2P2-ESP32')
      when 'picoruby-esp32'
        work_path = File.join(build_path, 'R2P2-ESP32', 'components', 'picoruby-esp32')
      when 'picoruby'
        work_path = File.join(build_path, 'R2P2-ESP32', 'components', 'picoruby-esp32', 'picoruby')
      end

      next unless Dir.exist?(work_path)

      Dir.chdir(work_path) do
        # 変更ファイルを取得
        changed_files = `git diff --name-only 2>/dev/null`.split("\n")

        if changed_files.empty?
          puts "  #{repo}: (no changes)"
          next
        end

        puts "  #{repo}: #{changed_files.size} file(s)"

        changed_files.each do |file|
          patch_dir = File.join(PicoRubyEnv::PATCH_DIR, repo)
          FileUtils.mkdir_p(patch_dir) unless Dir.exist?(patch_dir)

          # ディレクトリ構造を作成
          file_dir = File.dirname(file)
          unless file_dir == '.'
            FileUtils.mkdir_p(File.join(patch_dir, file_dir))
          end

          # 差分を取得して保存
          diff_output = `git diff #{Shellwords.escape(file)}`
          patch_file = File.join(patch_dir, file)

          if diff_output.strip.empty?
            # git diffが空の場合、ファイル全体をコピー
            FileUtils.cp(file, patch_file)
          else
            # 差分をファイルに保存
            File.write(patch_file, diff_output)
          end

          puts "    Exported: #{repo}/#{file}"
        end
      end
    end

    puts "✓ Patches exported"
  end

  desc 'パッチを適用: rake patch:apply[env_name]'
  task :apply, [:env_name] do |_t, args|
    env_name = args[:env_name] || 'current'

    # currentの場合はsymlinkから実環境名を取得
    if env_name == 'current'
      current_link = File.join(PicoRubyEnv::BUILD_DIR, 'current')
      if File.symlink?(current_link)
        current = PicoRubyEnv.get_current_env
        env_name = current if current
      else
        # currentが設定されていない場合は、パッチ適用をスキップ
        puts "  (No current environment - skipping patch apply)"
        next
      end
    end

    env_config = PicoRubyEnv.get_environment(env_name)
    raise "Error: Environment '#{env_name}' not found" if env_config.nil?

    r2p2_hash = env_config['R2P2-ESP32']['commit'] + '-' + env_config['R2P2-ESP32']['timestamp']
    esp32_hash = env_config['picoruby-esp32']['commit'] + '-' + env_config['picoruby-esp32']['timestamp']
    picoruby_hash = env_config['picoruby']['commit'] + '-' + env_config['picoruby']['timestamp']
    env_hash = PicoRubyEnv.generate_env_hash(r2p2_hash, esp32_hash, picoruby_hash)

    build_path = PicoRubyEnv.get_build_path(env_hash)
    raise "Error: Build environment not found: #{env_name}" unless Dir.exist?(build_path)

    puts "  Applying patches..."

    %w[R2P2-ESP32 picoruby-esp32 picoruby].each do |repo|
      patch_repo_dir = File.join(PicoRubyEnv::PATCH_DIR, repo)
      next unless Dir.exist?(patch_repo_dir)

      case repo
      when 'R2P2-ESP32'
        work_path = File.join(build_path, 'R2P2-ESP32')
      when 'picoruby-esp32'
        work_path = File.join(build_path, 'R2P2-ESP32', 'components', 'picoruby-esp32')
      when 'picoruby'
        work_path = File.join(build_path, 'R2P2-ESP32', 'components', 'picoruby-esp32', 'picoruby')
      end

      next unless Dir.exist?(work_path)

      # patch/repo配下のファイルをrecursiveに適用
      Dir.glob("#{patch_repo_dir}/**/*").sort.each do |patch_file|
        next if File.directory?(patch_file)
        next if File.basename(patch_file) == '.keep'

        rel_path = patch_file.sub("#{patch_repo_dir}/", '')
        dest_file = File.join(work_path, rel_path)

        FileUtils.mkdir_p(File.dirname(dest_file))
        FileUtils.cp(patch_file, dest_file)
      end

      puts "    Applied #{repo}"
    end

    puts "  ✓ Patches applied"
  end

  desc '差分を表示: rake patch:diff[env_name]'
  task :diff, [:env_name] do |_t, args|
    env_name = args[:env_name] || 'current'

    # currentの場合はsymlinkから実環境名を取得
    if env_name == 'current'
      current_link = File.join(PicoRubyEnv::BUILD_DIR, 'current')
      if File.symlink?(current_link)
        current = PicoRubyEnv.get_current_env
        env_name = current if current
      else
        raise "Error: No current environment set"
      end
    end

    env_config = PicoRubyEnv.get_environment(env_name)
    raise "Error: Environment '#{env_name}' not found" if env_config.nil?

    r2p2_hash = env_config['R2P2-ESP32']['commit'] + '-' + env_config['R2P2-ESP32']['timestamp']
    esp32_hash = env_config['picoruby-esp32']['commit'] + '-' + env_config['picoruby-esp32']['timestamp']
    picoruby_hash = env_config['picoruby']['commit'] + '-' + env_config['picoruby']['timestamp']
    env_hash = PicoRubyEnv.generate_env_hash(r2p2_hash, esp32_hash, picoruby_hash)

    build_path = PicoRubyEnv.get_build_path(env_hash)
    raise "Error: Build environment not found: #{env_name}" unless Dir.exist?(build_path)

    puts "=== Patch Differences ===\n"

    %w[R2P2-ESP32 picoruby-esp32 picoruby].each do |repo|
      patch_repo_dir = File.join(PicoRubyEnv::PATCH_DIR, repo)

      case repo
      when 'R2P2-ESP32'
        work_path = File.join(build_path, 'R2P2-ESP32')
      when 'picoruby-esp32'
        work_path = File.join(build_path, 'R2P2-ESP32', 'components', 'picoruby-esp32')
      when 'picoruby'
        work_path = File.join(build_path, 'R2P2-ESP32', 'components', 'picoruby-esp32', 'picoruby')
      end

      puts "#{repo}:"

      if Dir.exist?(work_path)
        Dir.chdir(work_path) do
          changed = `git diff --name-only 2>/dev/null`.split("\n")
          if changed.empty?
            puts "  (no working changes)"
          else
            puts "  Working changes: #{changed.join(', ')}"
          end
        end
      end

      if Dir.exist?(patch_repo_dir)
        patch_files = Dir.glob("#{patch_repo_dir}/**/*").reject { |p| File.directory?(p) || File.basename(p) == '.keep' }
        if patch_files.empty?
          puts "  (no stored patches)"
        else
          puts "  Stored patches: #{patch_files.map { |p| p.sub("#{patch_repo_dir}/", '') }.join(', ')}"
        end
      else
        puts "  (no patches directory)"
      end

      puts
    end
  end
end

# R2P2-ESP32のrakeタスク透過移譲

def delegate_to_r2p2(command, env_name = 'current')
  # currentの場合はsymlinkから実環境名を取得
  if env_name == 'current'
    current_link = File.join(PicoRubyEnv::BUILD_DIR, 'current')
    if File.symlink?(current_link)
      current = PicoRubyEnv.get_current_env
      env_name = current if current
    else
      raise "Error: No current environment set. Use 'rake env:set[env_name]' first"
    end
  end

  env_config = PicoRubyEnv.get_environment(env_name)
  raise "Error: Environment '#{env_name}' not found" if env_config.nil?

  r2p2_hash = env_config['R2P2-ESP32']['commit'] + '-' + env_config['R2P2-ESP32']['timestamp']
  esp32_hash = env_config['picoruby-esp32']['commit'] + '-' + env_config['picoruby-esp32']['timestamp']
  picoruby_hash = env_config['picoruby']['commit'] + '-' + env_config['picoruby']['timestamp']
  env_hash = PicoRubyEnv.generate_env_hash(r2p2_hash, esp32_hash, picoruby_hash)

  build_path = PicoRubyEnv.get_build_path(env_hash)
  raise "Error: Build environment not found: #{env_name}" unless Dir.exist?(build_path)

  r2p2_path = File.join(build_path, 'R2P2-ESP32')
  raise "Error: R2P2-ESP32 not found in build environment" unless Dir.exist?(r2p2_path)

  # ESP-IDF環境でR2P2-ESP32のrakeタスクを実行
  PicoRubyEnv.execute_with_esp_env("rake #{command}", r2p2_path)
end

desc 'ビルド: rake build[env_name]'
task :build, [:env_name] do |_t, args|
  env_name = args[:env_name] || 'current'
  puts "Building: #{env_name}"
  delegate_to_r2p2('build', env_name)
  puts "✓ Build completed"
end

desc 'フラッシュ: rake flash[env_name]'
task :flash, [:env_name] do |_t, args|
  env_name = args[:env_name] || 'current'
  puts "Flashing: #{env_name}"
  delegate_to_r2p2('flash', env_name)
  puts "✓ Flash completed"
end

desc 'モニター: rake monitor[env_name]'
task :monitor, [:env_name] do |_t, args|
  env_name = args[:env_name] || 'current'
  puts "Monitoring: #{env_name}"
  puts "(Press Ctrl+C to exit)"
  delegate_to_r2p2('monitor', env_name)
end
