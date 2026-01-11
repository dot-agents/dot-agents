#!/bin/bash
# dot-agents/lib/platforms/claude-code.sh
# Claude Code CLI detection, version, and linking

# Detect Claude Code CLI version
claude_detect() {
  if command -v claude >/dev/null 2>&1; then
    claude --version 2>/dev/null | head -1
  fi
}

# Check if Claude Code is installed
claude_is_installed() {
  command -v claude >/dev/null 2>&1
}

# Get Claude Code version string
claude_version() {
  claude_detect
}

# Create links for Claude Code (SYMLINKS - works fine)
claude_create_links() {
  local project="$1"
  local repo_path="$2"

  # Link CLAUDE.md from global rules if it exists
  if [ -f "$AGENTS_HOME/rules/global/claude.md" ]; then
    ln -sf "$AGENTS_HOME/rules/global/claude.md" "$repo_path/CLAUDE.md"
  elif [ -f "$AGENTS_HOME/rules/global/rules.md" ]; then
    # Fall back to global rules.md if no claude-specific file
    ln -sf "$AGENTS_HOME/rules/global/rules.md" "$repo_path/CLAUDE.md"
  fi

  # Project-specific CLAUDE.md
  if [ -f "$AGENTS_HOME/rules/$project/claude.md" ]; then
    # If project has its own claude.md, use it instead
    ln -sf "$AGENTS_HOME/rules/$project/claude.md" "$repo_path/CLAUDE.md"
  fi

  # Create .claude directory for settings
  mkdir -p "$repo_path/.claude"

  # Link settings.local.json if exists
  if [ -f "$AGENTS_HOME/settings/$project/claude-code.json" ]; then
    ln -sf "$AGENTS_HOME/settings/$project/claude-code.json" "$repo_path/.claude/settings.local.json"
  fi

  # Link MCP config if exists
  if [ -f "$AGENTS_HOME/mcp/$project/claude.json" ]; then
    ln -sf "$AGENTS_HOME/mcp/$project/claude.json" "$repo_path/.mcp.json"
  elif [ -f "$AGENTS_HOME/mcp/global/claude.json" ]; then
    ln -sf "$AGENTS_HOME/mcp/global/claude.json" "$repo_path/.mcp.json"
  fi
}

# Check for deprecated .claude.json file
claude_has_deprecated_format() {
  local repo_path="$1"
  [ -f "$repo_path/.claude.json" ]
}

# Get deprecated format details
claude_deprecated_details() {
  local repo_path="$1"

  if [ -f "$repo_path/.claude.json" ]; then
    echo ".claude.json → .claude/settings.json"
  fi
}

# Check if global Claude settings are managed by dot-agents
claude_global_settings_managed() {
  local claude_settings="$HOME/.claude/settings.json"
  local agents_settings="$AGENTS_HOME/settings/global/claude-code-global.json"

  # Check if settings.json is a symlink pointing to our managed file
  if [ -L "$claude_settings" ]; then
    local target
    target=$(readlink "$claude_settings" 2>/dev/null)
    [ "$target" = "$agents_settings" ]
  else
    return 1
  fi
}

# Set up global Claude settings management
# Creates symlink from ~/.claude/settings.json → ~/.agents/settings/global/claude-code-global.json
claude_setup_global_settings() {
  local force="${1:-false}"
  local claude_dir="$HOME/.claude"
  local claude_settings="$claude_dir/settings.json"
  local agents_settings="$AGENTS_HOME/settings/global/claude-code-global.json"

  # Create ~/.claude directory if needed
  mkdir -p "$claude_dir"

  # Create ~/.agents/settings/global if needed
  mkdir -p "$AGENTS_HOME/settings/global"

  # Handle existing settings.json
  if [ -e "$claude_settings" ]; then
    if [ -L "$claude_settings" ]; then
      # Already a symlink
      local target
      target=$(readlink "$claude_settings" 2>/dev/null)
      if [ "$target" = "$agents_settings" ]; then
        echo "already_managed"
        return 0
      else
        # Symlink points elsewhere
        if [ "$force" = true ]; then
          rm "$claude_settings"
        else
          echo "symlink_conflict:$target"
          return 1
        fi
      fi
    else
      # Regular file exists
      if [ "$force" = true ]; then
        # Backup and migrate
        if [ ! -f "$agents_settings" ]; then
          cp "$claude_settings" "$agents_settings"
        fi
        mv "$claude_settings" "$claude_settings.backup"
        echo "migrated"
      else
        echo "file_exists"
        return 1
      fi
    fi
  fi

  # Create the managed settings file if it doesn't exist
  if [ ! -f "$agents_settings" ]; then
    echo '{}' > "$agents_settings"
  fi

  # Create symlink
  ln -sf "$agents_settings" "$claude_settings"
  echo "linked"
  return 0
}

# Get Claude global settings status
claude_global_settings_status() {
  local claude_settings="$HOME/.claude/settings.json"
  local agents_settings="$AGENTS_HOME/settings/global/claude-code-global.json"

  if [ ! -e "$claude_settings" ]; then
    echo "not_found"
  elif [ -L "$claude_settings" ]; then
    local target
    target=$(readlink "$claude_settings" 2>/dev/null)
    if [ "$target" = "$agents_settings" ]; then
      echo "managed"
    else
      echo "symlink_other:$target"
    fi
  else
    echo "unmanaged_file"
  fi
}
