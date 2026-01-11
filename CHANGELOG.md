# Changelog

All notable changes to dot-agents will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.8] - 2026-01-11

### Added

- **Unified Skills Architecture**
  - `skills` - New CLI command to manage directory-based skills
  - `skills new <name>` - Create a new skill from template
  - `skills edit <name>` - Open skill's SKILL.md in $EDITOR
  - `skills show <name>` - Display skill contents
  - `skills validate <name>` - Validate skill frontmatter
  - `skills migrate` - Migrate from old flat commands/ format
  - `link --global` - Link global skills to all platforms
- **Directory-based Skill Structure**
  - Each skill is a directory with SKILL.md (not a flat .md file)
  - Optional scripts/ and references/ subdirectories
  - YAML frontmatter for metadata (description, platforms, etc.)
- **Default Skills**
  - `agent-start` - Session startup procedure
  - `agent-handoff` - Session handoff procedure
  - `self-review` - Pre-commit checklist
- **Multi-Platform Skills Integration**
  - Claude Code: Symlinks directories to `.claude/skills/`
  - Cursor: Symlinks SKILL.md to `.cursor/commands/{name}.md`
  - Codex CLI: Symlinks directories to `.codex/skills/`
  - No prefix required - `/agent-start` not `/global--agent-start`
  - Project skills shadow global skills (with CLI warning)

### Changed

- `doctor` now checks for skills directory structure and symlinks
- `init` now creates `~/.agents/skills/global/` with skill templates
- `add` now creates platform-specific skill symlinks automatically

## [0.1.7] - 2026-01-11

### Added

- **Claude Code Hooks Support**
  - `hooks` - New CLI command to manage hooks
  - `hooks list` - List configured hooks
  - `hooks add` - Add a new hook
  - `hooks remove` - Remove a hook
  - Global hooks in `~/.agents/settings/global/claude-code.json`
  - Project hooks in `~/.agents/settings/<project>/claude-code.json`
- Settings templates created during `init` and `add`

### Changed

- `doctor` now validates hooks configuration
- `init` creates settings templates with hooks examples

### Fixed

- bash 3.x compatibility (removed `local -n` nameref)
- Empty array handling in strict mode

## [0.1.0] - 2026-01-10

### Added

- Initial release
- **Core Commands**
  - `init` - Initialize `~/.agents/` directory structure
  - `add <path>` - Add a project to dot-agents management
  - `remove <project>` - Remove a project from management
  - `status` - Show managed projects and their status
  - `doctor` - Health check and diagnostics
  - `audit` - Show which configs are applied where
- **Sync Commands**
  - `sync init` - Initialize git repository in `~/.agents/`
  - `sync status` - Show git status
  - `sync commit` - Commit all changes
  - `sync push` - Push to remote
  - `sync pull` - Pull from remote
  - `sync log` - Show recent commits
- **Utility Commands**
  - `context` - Output configuration as JSON for AI agents
- **Agent Support**
  - Cursor (`.cursor/rules/` with hard links)
  - Claude Code (`CLAUDE.md`, `.claude/` with symlinks)
  - Codex (`AGENTS.md` with symlinks)
  - OpenCode (detection only)
- **Installation**
  - Homebrew formula
  - curl install script
- **Features**
  - Automatic agent detection
  - Hard links for Cursor (required - doesn't follow symlinks)
  - Symlinks for Claude Code and Codex
  - JSON output for all inspection commands
  - Dry-run mode for all mutating commands
  - XDG-compliant state storage

### Notes

- Windows support deferred to future release
- Tasks and History features are opt-in and not yet implemented

[Unreleased]: https://github.com/dot-agents/dot-agents/compare/v0.1.8...HEAD
[0.1.8]: https://github.com/dot-agents/dot-agents/compare/v0.1.7...v0.1.8
[0.1.7]: https://github.com/dot-agents/dot-agents/compare/v0.1.0...v0.1.7
[0.1.0]: https://github.com/dot-agents/dot-agents/releases/tag/v0.1.0
