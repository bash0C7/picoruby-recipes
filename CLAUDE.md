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

⚠️ **IMPORTANT**: Do NOT execute `rake` commands autonomously. User must run these commands manually.

```bash
rake init        # Initial setup
rake build       # Build
rake cleanbuild  # Clean build
rake check_env   # Environment check
```

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
