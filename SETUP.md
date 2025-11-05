# PicoRuby Multi-Version Build System - Setup Guide

## Overview

This is a multi-version management system for PicoRuby ESP32 development. It allows you to maintain multiple versions of R2P2-ESP32, picoruby-esp32, and picoruby simultaneously with immutable caching and symlink-based environment switching.

## Quick Start

### 1. Unpack the Archive

```bash
unzip picoruby-buildscript.zip
cd picoruby-buildscript
```

### 2. Initialize Environment

Create your first environment in `.picoruby-env.yml`:

```yaml
current: stable

environments:
  stable:
    R2P2-ESP32:
      commit: f500652  # Replace with desired commit
      timestamp: "20241105_143022"
    picoruby-esp32:
      commit: 6a6da3a
      timestamp: "20241105_142015"
    picoruby:
      commit: e57c370
      timestamp: "20241105_141030"
    created_at: "2024-11-05 14:30:22"
```

### 3. Fetch and Build

```bash
# Fetch repositories to .cache/
rake -f Rakefile.rb cache:fetch[stable]

# Create build environment
rake -f Rakefile.rb build:setup[stable]

# Build the project
rake -f Rakefile.rb build

# Flash to ESP32
rake -f Rakefile.rb flash

# Monitor serial output
rake -f Rakefile.rb monitor
```

## Directory Structure

```
.
├── Rakefile.rb              # New multi-version build system
├── RAKEFILE_SPEC.md        # Complete specification (Japanese)
├── CLAUDE.md               # Development guidelines
├── TODO.md                 # Maintenance roadmap
├── .picoruby-env.yml       # Environment configuration
├── storage/home/           # Your application code
├── patch/                  # Patch management
├── .cache/                 # Immutable cached repositories
└── build/                  # Build environments
```

## Key Concepts

### Immutable Cache (.cache/)

- Repositories are cached with `commit-timestamp` naming
- Once created, never modified
- Version changes mean creating new cache entries

### Environment Switching (build/current)

- `build/current` is a symlink to the active environment
- Switch environments with: `rake env:set[env_name]`
- Automatically updates when using `build:setup`

### Patch Management

- Changes to upstream repos go in `patch/` directory
- Auto-applied when setting up new build environments
- Sync working changes back with: `rake patch:export`

## Available Tasks

See [RAKEFILE_SPEC.md](RAKEFILE_SPEC.md) for complete documentation.

Quick reference:
```bash
rake -f Rakefile.rb env:show          # Show current environment
rake -f Rakefile.rb cache:list        # List cached versions
rake -f Rakefile.rb build:list        # List build environments
rake -f Rakefile.rb build:setup[env]  # Create build environment
rake -f Rakefile.rb patch:export      # Export patches to Git
```

## For New Environments

When you need to test a new version combination:

```bash
# 1. Add to .picoruby-env.yml
# 2. Fetch the repositories
rake -f Rakefile.rb cache:fetch[new_env]

# 3. Build and test
rake -f Rakefile.rb build:setup[new_env]
rake -f Rakefile.rb build[new_env]
```

## Notes

- Requirements: ESP-IDF, Ruby with FileUtils, Git
- Tested with: ESP32, R2P2-ESP32, PicoRuby
- See CLAUDE.md for development conventions

## Support

Refer to RAKEFILE_SPEC.md for detailed task documentation and troubleshooting.
