=begin
ESP32 PicoRuby装置開発汎用ビルドスクリプト

このRakefileは、ESP32上でPicoRubyを使用する装置開発のための
汎用ビルドスクリプトとして設計されている。

【システム概要】
ESP32 + PicoRuby（R2P2-ESP32）環境での統合開発を支援。
Arduino C++とRuby（PicoRuby）のハイブリッド構成によるマイクロコントローラー開発。

【主要機能】
- ESP-IDF環境の自動セットアップ（Homebrew OpenSSL対応）
- R2P2-ESP32（PicoRuby）との統合ビルド
- Arduino C++とRubyのハイブリッド開発サポート
- 自動的なソースコンポーネント管理（src_components/ → components/）
- 段階的なビルド・フラッシュ・モニタリング

【利用可能なタスク】
  rake init        # 初期セットアップ：componentsディレクトリ作成、R2P2-ESP32クローン、ソースディレクトリ作成、ソースコピー、ビルド実行
  rake update      # 更新：git変更クリーン、最新版プル、ソースコピー、リビルド実行
  rake cleanbuild  # クリーンビルド：fullclean、setup_esp32、rake実行
  rake buildall    # 全体ビルド：setup_esp32とrake buildの実行
  rake build       # ビルド：rake buildのみ実行
  rake flash       # フラッシュ：ESP32にプログラム書き込み
  rake monitor     # モニタ：ESP32シリアル出力監視
  rake check_env   # 環境チェック：ESP-IDF環境とコマンドの確認

【開発フロー】
1. 初回セットアップ：rake init（src_components/R2P2-ESP32/storage/home/自動作成）
2. 通常の開発：rake build && rake flash && rake monitor
3. 依存関係更新：rake update
4. 完全リビルド：rake cleanbuild

【ディレクトリ構造】
プロジェクトルート/
├── src_components/          # ソースコンポーネント（Git管理対象）
│   └── R2P2-ESP32/
│       └── storage/home/    # Rubyファイル配置場所
└── components/              # ビルド用ディレクトリ（Git管理対象外）
    └── R2P2-ESP32/          # クローンされたPicoRubyランタイム
        └── storage/home/    # Rubyファイル実行場所

【パス管理】
- ソース→ターゲット：src_components/ → components/
- Rubyファイル配置：components/R2P2-ESP32/storage/home/
- ビルド時に自動コピー、サブディレクトリは削除してファイルのみ保持

【環境要件】
- ESP-IDF: $HOME/esp/esp-idf/
- Homebrew OpenSSL: /opt/homebrew/opt/openssl
- Git with submodule support
- Ruby with FileUtils
=end

require 'fileutils'

# Common environment setup for all tasks
def setup_environment
  # Set OpenSSL paths for Homebrew
  homebrew_openssl = "/opt/homebrew/opt/openssl"
  
  env_vars = {
    'PATH' => "#{homebrew_openssl}/bin:#{ENV['PATH']}",
    'LDFLAGS' => "-L#{homebrew_openssl}/lib #{ENV['LDFLAGS']}",
    'CPPFLAGS' => "-I#{homebrew_openssl}/include #{ENV['CPPFLAGS']}",
    'CFLAGS' => "-I#{homebrew_openssl}/include #{ENV['CFLAGS']}",
    'PKG_CONFIG_PATH' => "#{homebrew_openssl}/lib/pkgconfig:#{ENV['PKG_CONFIG_PATH']}",
    'GRPC_PYTHON_BUILD_SYSTEM_OPENSSL' => '1',
    'GRPC_PYTHON_BUILD_SYSTEM_ZLIB' => '1',
    'ESPBAUD' => '115200'
  }
  
  # Set basic ESP-IDF path
  esp_idf_path = "#{ENV['HOME']}/esp/esp-idf"
  if Dir.exist?(esp_idf_path)
    env_vars['IDF_PATH'] = esp_idf_path
  else
    puts "Critical Warning: ESP-IDF not found at #{esp_idf_path}"
    puts "Please install ESP-IDF or update the path in setup_environment method"
  end
  
  # Apply environment variables
  env_vars.each { |key, value| ENV[key] = value }
  
  puts "Environment setup complete"
  puts "IDF_PATH: #{ENV['IDF_PATH']}"
  
  # Note: Actual ESP-IDF tools will be available after sourcing export.sh in execute_with_esp_env
end

# Helper method to execute commands in R2P2-ESP32 directory with proper error handling
def execute_in_r2p2_directory(commands)
  Dir.chdir('components/R2P2-ESP32') do
    commands.each do |cmd|
      puts "Executing: #{cmd}"
      unless system(cmd)
        abort "Error: Command failed with exit code #{$?.exitstatus}: #{cmd}"
      end
    end
  end
end

# Helper method to execute shell command that sources ESP-IDF environment
def execute_with_esp_env(command)
  esp_idf_path = ENV['IDF_PATH'] || "#{ENV['HOME']}/esp/esp-idf"
  
  # Create a comprehensive environment setup script
  setup_script = <<~SCRIPT
    export PATH="/opt/homebrew/opt/openssl/bin:$PATH"
    export LDFLAGS="-L/opt/homebrew/opt/openssl/lib $LDFLAGS"
    export CPPFLAGS="-I/opt/homebrew/opt/openssl/include $CPPFLAGS"
    export CFLAGS="-I/opt/homebrew/opt/openssl/include $CFLAGS"
    export PKG_CONFIG_PATH="/opt/homebrew/opt/openssl/lib/pkgconfig:$PKG_CONFIG_PATH"
    export GRPC_PYTHON_BUILD_SYSTEM_OPENSSL=1
    export GRPC_PYTHON_BUILD_SYSTEM_ZLIB=1
    export ESPBAUD=115200
    
    # Source ESP-IDF environment
    . #{esp_idf_path}/export.sh
    
    # Execute the command
    #{command}
  SCRIPT
  
  puts "Executing with ESP-IDF environment: #{command}"
  success = system("bash", "-c", setup_script)
  
  unless success
    abort "Error: ESP-IDF command failed with exit code #{$?.exitstatus}: #{command}"
  end
  
  success
end

# Helper method to check if commands are available in ESP-IDF environment
def check_commands_in_esp_env
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
    
    # Source ESP-IDF environment
    . #{esp_idf_path}/export.sh
    
    # Check commands
    echo "=== Commands after ESP-IDF setup ==="
    echo "python: $(which python || echo 'Not found')"
    echo "python3: $(which python3 || echo 'Not found')"
    echo "idf.py: $(which idf.py || echo 'Not found')"
    echo "xtensa-esp32-elf-gcc: $(which xtensa-esp32-elf-gcc || echo 'Not found')"
    
    # Return success if all essential commands are found
    if command -v python >/dev/null 2>&1 && command -v idf.py >/dev/null 2>&1 && command -v xtensa-esp32-elf-gcc >/dev/null 2>&1; then
      echo "All essential commands available"
      exit 0
    else
      echo "Some commands are missing"
      exit 1
    fi
  SCRIPT
  
  system("bash", "-c", setup_script)
end

# Helper method to copy source components contents
def copy_source_components
  source_dir = 'src_components'
  target_dir = 'components'
  
  if Dir.exist?(source_dir)
    begin
      FileUtils.cp_r("#{source_dir}/.", target_dir)
      puts "Copied src_components contents to #{target_dir}"
      
      # Remove only dot directories and vendor directories in components/R2P2-ESP32/storage/home
      home_dir = File.join(target_dir, 'R2P2-ESP32', 'storage', 'home')
      if Dir.exist?(home_dir)
        Dir.foreach(home_dir) do |item|
          next if item == '.' || item == '..'
          
          item_path = File.join(home_dir, item)
          if File.directory?(item_path) && (item.start_with?('.') || item == 'vendor')
            FileUtils.rm_rf(item_path)
            puts "Removed directory: #{item_path}"
          end
        end
      end
    rescue => e
      abort "Error: Failed to copy source components: #{e.message}"
    end
  else
    puts "Warning: #{source_dir} directory not found"
  end
end

desc "初期セットアップ：componentsディレクトリ作成、R2P2-ESP32クローン、ソースディレクトリ作成、ソースコピー、ビルド実行"
task :init do
  puts "Starting ESP32 PicoRuby project init..."
  setup_environment
  
  begin
    # Create components directory
    FileUtils.mkdir_p('components')
    puts "Created components directory"
    
    # Create source components directory structure
    src_home_dir = 'src_components/R2P2-ESP32/storage/home'
    FileUtils.mkdir_p(src_home_dir)
    puts "Created source components directory: #{src_home_dir}"
    
    # Clone R2P2-ESP32 repository
    Dir.chdir('components') do
      if Dir.exist?('R2P2-ESP32')
        puts "R2P2-ESP32 already exists, skipping clone"
      else
        unless system('git clone --recursive https://github.com/picoruby/R2P2-ESP32.git')
          abort "Error: Failed to clone R2P2-ESP32 repository"
        end
        puts "Cloned R2P2-ESP32 repository"
      end
    end
    
    # Copy source components contents
    copy_source_components
    
    # Execute build commands in R2P2-ESP32 directory with ESP-IDF environment
    Dir.chdir('components/R2P2-ESP32') do
      execute_with_esp_env('idf.py fullclean')
      execute_with_esp_env('rake setup_esp32')
      execute_with_esp_env('rake build')
    end
  rescue => e
    abort "Error during setup: #{e.message}"
  end
  
  puts "Setup completed successfully"
end

desc "更新：git変更クリーン、最新版プル、ソースコピー、リビルド実行"
task :update do
  puts "Updating ESP32 PicoRuby project..."
  setup_environment
  
  begin
    Dir.chdir('components/R2P2-ESP32') do
      # Clean git changes and untracked files
      unless system('git reset --hard HEAD')
        abort "Error: Failed to reset git repository"
      end
      unless system('git clean -fd')
        abort "Error: Failed to clean git repository"
      end
      puts "Cleaned git changes and untracked files"
      
      # Reset and clean all submodules recursively
      unless system('git submodule foreach --recursive git reset --hard HEAD')
        abort "Error: Failed to reset submodules"
      end
      unless system('git submodule foreach --recursive git clean -fd')
        abort "Error: Failed to clean submodules"
      end
      puts "Cleaned all submodules recursively"
      
      # Pull latest changes with submodules
      unless system('git pull --recurse-submodules')
        abort "Error: Failed to pull latest changes"
      end
      
      # Update submodules to latest
      unless system('git submodule update --init --recursive --remote')
        abort "Error: Failed to update submodules"
      end
      puts "Updated to latest with all submodules"
    end
    
    # Copy source components contents
    copy_source_components
    
    # Execute build commands with ESP-IDF environment
    Dir.chdir('components/R2P2-ESP32') do
      execute_with_esp_env('idf.py fullclean')
      execute_with_esp_env('rake setup_esp32')
      execute_with_esp_env('rake build')
    end
  rescue => e
    abort "Error during update: #{e.message}"
  end
  
  puts "Update completed successfully"
end

desc "クリーンビルド：fullclean、setup_esp32、rake実行"
task :cleanbuild do
  puts "Performing clean build..."
  setup_environment
  copy_source_components
  
  begin
    Dir.chdir('components/R2P2-ESP32') do
      execute_with_esp_env('idf.py fullclean')
      execute_with_esp_env('rake setup_esp32')
      execute_with_esp_env('rake')
    end
  rescue => e
    abort "Error during clean build: #{e.message}"
  end
  
  puts "Clean build completed successfully"
end

desc "全体ビルド：setup_esp32とrake buildの実行"
task :buildall do
  puts "Building all components..."
  setup_environment
  copy_source_components
  
  begin
    Dir.chdir('components/R2P2-ESP32') do
      execute_with_esp_env('rake setup_esp32')
      execute_with_esp_env('rake build')
    end
  rescue => e
    abort "Error during build all: #{e.message}"
  end
  
  puts "Build all completed successfully"
end

desc "ビルド：rake buildのみ実行"
task :build do
  puts "Building project..."
  setup_environment
  copy_source_components
  
  begin
    Dir.chdir('components/R2P2-ESP32') do
      execute_with_esp_env('rake build')
    end
  rescue => e
    abort "Error during build: #{e.message}"
  end
  
  puts "Build completed successfully"
end

desc "フラッシュ：ESP32にプログラム書き込み"
task :flash do
  puts "flash project..."
  setup_environment
  
  begin
    Dir.chdir('components/R2P2-ESP32') do
      execute_with_esp_env('rake flash')
    end
  rescue => e
    abort "Error during flash: #{e.message}"
  end
  
  puts "flash completed successfully"
end

desc "モニタ：ESP32シリアル出力監視"
task :monitor do
  puts "monitor project..."
  setup_environment
  
  begin
    Dir.chdir('components/R2P2-ESP32') do
      execute_with_esp_env('rake monitor')
    end
  rescue => e
    abort "Error during monitor: #{e.message}"
  end
  
  puts "monitor completed successfully"
end

desc "環境チェック：ESP-IDF環境とコマンドの確認"
task :check_env do
  setup_environment
  
  puts "\n=== Basic Environment Check ==="
  puts "IDF_PATH: #{ENV['IDF_PATH']}"
  
  esp_idf_exists = File.exist?(ENV['IDF_PATH'] || '')
  puts "ESP-IDF exists: #{esp_idf_exists ? 'Yes' : 'No'}"
  
  unless esp_idf_exists
    puts "Error: ESP-IDF not found. Please install ESP-IDF or update the path."
    abort "ESP-IDF installation required"
  end
  
  puts "\n=== Checking commands without ESP-IDF environment ==="
  # Check basic commands first
  ['python3', 'git', 'cmake'].each do |cmd|
    available = system("which #{cmd}", out: File::NULL, err: File::NULL)
    puts "#{cmd}: #{available ? 'Available' : 'Not found'}"
  end
  
  puts "\n=== Checking ESP-IDF environment ==="
  # Check commands with ESP-IDF environment loaded
  if check_commands_in_esp_env
    puts "=== Environment Check Passed ==="
    puts "ESP-IDF environment is properly configured"
  else
    puts "\nError: ESP-IDF environment setup failed"
    puts "Please check your ESP-IDF installation:"
    puts "1. Ensure ESP-IDF is installed at #{ENV['IDF_PATH']}"
    puts "2. Run: #{ENV['IDF_PATH']}/install.sh"
    puts "3. Test manually: source #{ENV['IDF_PATH']}/export.sh"
    abort "ESP-IDF environment configuration failed"
  end
end

# Default task
task :default => [:build, :flash, :monitor]
