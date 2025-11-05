# ATOM Matrix ESP32 Project Guide

PicoRuby/mruby embedded development for ATOM Matrix (ESP32-PICO-D4) + R2P2-ESP32 runtime.

## Fundamental Principles

**Simplicity First**: Avoid complexity. Write simple, linear code by default.

**Proactive Implementation**: Implement without asking, commit immediately (using `commit` subagent), user verifies after.

**Evidence-Based Answers**: Never speculate. Read files first, use `explore` subagent for code investigation.

**Parallel Tool Calls**: Read multiple files/grep in parallel when independent. Never use placeholders.

## Output Style

```
🎯 **日本語で出力すること**:
- 絶対に日本語で応答・プラン提示
- 通常: 語尾に「ピョン。」をつけて可愛く
- 盛り上がったら: 「チェケラッチョ！！」と叫ぶ
- コード内コメント: 日本語、体言止め
- ドキュメント(.md): 英語で記述
- Git commit: 英語、命令形
```

## Rake Commands Permissions

⚠️ **Do NOT execute rake commands without user approval**

| Command | Status | Reason |
|---------|--------|--------|
| `rake monitor`, `rake check_env` | ✅ Allowed | Read-only, safe |
| `rake build`, `rake cleanbuild`, `rake flash` | ❓ Ask first | Time-consuming or hardware operations |
| `rake init`, `rake update`, `rake buildall` | 🚫 Denied | Contains `git reset --hard` (destructive) |

**Rationale**: Protect work-in-progress from accidental destructive operations.

## Code Style

**Ruby (.rb files - PicoRuby/mruby)**:
- See `picoruby-constraints` skill: Memory limits (520KB), shallow nesting, pre-allocation
- Comments: Japanese, noun-ending style (体言止め)
- PicoRuby stdlib ONLY (no CRuby gems, no bundler)

**Git Commits**:
- English, imperative mood
- ⚠️ MUST use `commit` subagent (never direct git commands)
- Forbidden: `git push`, `git push --force`

**Documentation (.md files)**: English

## Skills & Auto-Loading

Claude automatically loads specialized expertise when needed:

| Skill | When Loaded | Content |
|-------|------------|---------|
| `picoruby-constraints` | `.rb` files, memory optimization | PicoRuby vs CRuby, stdlib limits, memory patterns |
| `atom-matrix-hardware` | GPIO, sensors, pins, LED wiring | ESP32 pinout, MPU6886, WS2812, UART protocols |
| `finger-drum` | Drum performance, MIDI, protocol | DDJ-400 integration, system architecture |
| `led-visualization` | LED effects, color algorithms | PAD tracking, acceleration-driven colors |

**No memorization needed** — skills load on-demand with appropriate trigger keywords.

## Project Structure

- **Ruby apps**: `src_components/R2P2-ESP32/storage/home/app.rb` (auto-runs on boot)
- **Build config**: `build_config/xtensa-esp.rb`
- **Hardware**: ATOM Matrix (5x5 matrix, GPIO pins, I2C, UART)
- **Build System**: ESP-IDF + R2P2-ESP32

## Workflow

1. **Investigate** (use `explore` subagent for code reviews)
2. **Plan** (when needed, use ExitPlanMode)
3. **Implement** (small, incremental changes)
4. **Commit** (use `commit` subagent immediately)
5. **User Verifies** (after commit, not before)
