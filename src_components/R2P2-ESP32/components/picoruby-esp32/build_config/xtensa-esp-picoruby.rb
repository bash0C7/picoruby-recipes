MRuby::CrossBuild.new('esp32-picoruby') do |conf|
  conf.toolchain('gcc')

  conf.cc.command = "xtensa-#{ENV['CONFIG_IDF_TARGET']}-elf-gcc"
  conf.linker.command = "xtensa-#{ENV['CONFIG_IDF_TARGET']}-elf-ld"
  conf.archiver.command = "xtensa-#{ENV['CONFIG_IDF_TARGET']}-elf-ar"

  conf.cc.host_command = 'gcc'
  conf.cc.flags << '-Wall'
  conf.cc.flags << '-Wno-format'
  conf.cc.flags << '-Wno-unused-function'
  conf.cc.flags << '-Wno-maybe-uninitialized'
  conf.cc.flags << '-mlongcalls'

  conf.cc.defines << 'MRB_TICK_UNIT=10'
  conf.cc.defines << 'MRB_TIMESLICE_TICK_COUNT=1'
  conf.cc.defines << 'MRBC_CONVERT_CRLF=1'
  conf.cc.defines << 'MRB_UTF8_STRING'
  conf.cc.defines << 'MRB_INT64'
  conf.cc.defines << 'MRB_NO_BOXING'
  conf.cc.defines << 'MRB_32BIT'
  conf.cc.defines << 'PICORB_ALLOC_ESTALLOC'
  conf.cc.defines << 'PICORB_ALLOC_ALIGN=8'
  conf.cc.defines << 'USE_FAT_FLASH_DISK'
  conf.cc.defines << 'NDEBUG'
  conf.cc.defines << 'ESP32_PLATFORM'

  if ENV['PICORB_DEBUG']
    conf.cc.defines << 'ESTALLOC_DEBUG'
    conf.enable_debug
  end

  conf.picoruby
  conf.gembox 'minimum'
  conf.gembox 'core'

  # mruby extensions — minimum needed for mpu6886 + test scripts
  conf.gem gemdir: '../picoruby/mrbgems/picoruby-mruby/lib/mruby/mrbgems/mruby-kernel-ext'
  conf.gem gemdir: '../picoruby/mrbgems/picoruby-mruby/lib/mruby/mrbgems/mruby-string-ext'
  conf.gem gemdir: '../picoruby/mrbgems/picoruby-mruby/lib/mruby/mrbgems/mruby-array-ext'
  conf.gem gemdir: '../picoruby/mrbgems/picoruby-mruby/lib/mruby/mrbgems/mruby-error'
  conf.gem gemdir: '../picoruby/mrbgems/picoruby-mruby/lib/mruby/mrbgems/mruby-math'

  conf.gem core: 'picoruby-esp32'

  # shell gembox expanded — drops picoruby-vim + picoruby-rapicco (heavy, unused for IMU testing)
  conf.gem core: 'picoruby-shell'
  conf.gem core: 'picoruby-picoline'

  # peripherals (only I2C for MPU6886)
  conf.gem core: 'picoruby-i2c'

  # bash0C7 custom gems
  conf.gem github: 'bash0C7/picoruby-mpu6886', branch: 'feat/runtime-gem-modernization'
  conf.gem gemdir: File.expand_path('~/dev/src/github.com/bash0C7/picoruby-vl53l0x')
end
