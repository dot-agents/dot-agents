#!/bin/bash
# dot-agents/lib/platforms/cursor.sh
# Cursor IDE detection, version, and linking

# Detect Cursor App version (macOS)
cursor_detect_app() {
  if [ -d "/Applications/Cursor.app" ]; then
    defaults read /Applications/Cursor.app/Contents/Info.plist CFBundleShortVersionString 2>/dev/null
  fi
}

# Detect Cursor CLI version
cursor_detect_cli() {
  if command -v cursor >/dev/null 2>&1; then
    cursor --version 2>/dev/null | head -1
  fi
}

# Check if Cursor is installed (any method)
cursor_is_installed() {
  [ -d "/Applications/Cursor.app" ] || command -v cursor >/dev/null 2>&1
}

# Get Cursor version string
cursor_version() {
  local app_version cli_version

  app_version=$(cursor_detect_app)
  cli_version=$(cursor_detect_cli)

  if [ -n "$app_version" ] && [ -n "$cli_version" ]; then
    echo "$app_version (CLI: $cli_version)"
  elif [ -n "$app_version" ]; then
    echo "$app_version (App)"
  elif [ -n "$cli_version" ]; then
    echo "$cli_version"
  fi
}

# Create links for Cursor rules (HARD LINKS - Cursor doesn't follow symlinks)
cursor_create_rule_links() {
  local project="$1"
  local repo_path="$2"

  mkdir -p "$repo_path/.cursor/rules"

  # Global rules → prefixed with "global--"
  if [ -d "$AGENTS_HOME/rules/global" ]; then
    for rule in "$AGENTS_HOME/rules/global"/*.mdc "$AGENTS_HOME/rules/global"/*.md; do
      [ -f "$rule" ] || continue
      local basename
      basename=$(basename "$rule")
      # Convert .md to .mdc for Cursor if needed
      local target_name="$basename"
      [[ "$basename" == *.md ]] && [[ "$basename" != *.mdc ]] && target_name="${basename%.md}.mdc"
      ln -f "$rule" "$repo_path/.cursor/rules/global--$target_name" 2>/dev/null || true
    done
  fi

  # Project-specific rules → prefixed with "{project}--"
  if [ -d "$AGENTS_HOME/rules/$project" ]; then
    for rule in "$AGENTS_HOME/rules/$project"/*.mdc "$AGENTS_HOME/rules/$project"/*.md; do
      [ -f "$rule" ] || continue
      local basename
      basename=$(basename "$rule")
      local target_name="$basename"
      [[ "$basename" == *.md ]] && [[ "$basename" != *.mdc ]] && target_name="${basename%.md}.mdc"
      ln -f "$rule" "$repo_path/.cursor/rules/${project}--$target_name" 2>/dev/null || true
    done
  fi
}

# Check for deprecated .cursorrules file
cursor_has_deprecated_format() {
  local repo_path="$1"
  [ -f "$repo_path/.cursorrules" ]
}

# Get deprecated format details
cursor_deprecated_details() {
  local repo_path="$1"

  if [ -f "$repo_path/.cursorrules" ]; then
    echo ".cursorrules → .cursor/rules/*.mdc"
  fi
}

# Create links for Cursor settings (HARD LINKS)
cursor_create_settings_links() {
  local project="$1"
  local repo_path="$2"

  mkdir -p "$repo_path/.cursor"

  # Project-specific settings take priority
  if [ -f "$AGENTS_HOME/settings/$project/cursor.json" ]; then
    ln -f "$AGENTS_HOME/settings/$project/cursor.json" "$repo_path/.cursor/settings.json" 2>/dev/null || true
    return 0
  fi

  # Fall back to global settings
  if [ -f "$AGENTS_HOME/settings/global/cursor.json" ]; then
    ln -f "$AGENTS_HOME/settings/global/cursor.json" "$repo_path/.cursor/settings.json" 2>/dev/null || true
  fi
}

# Create links for Cursor MCP config (HARD LINKS)
cursor_create_mcp_links() {
  local project="$1"
  local repo_path="$2"

  mkdir -p "$repo_path/.cursor"

  # Project-specific MCP config takes priority
  if [ -f "$AGENTS_HOME/mcp/$project/cursor.json" ]; then
    ln -f "$AGENTS_HOME/mcp/$project/cursor.json" "$repo_path/.cursor/mcp.json" 2>/dev/null || true
    return 0
  fi

  # Fall back to global MCP config
  if [ -f "$AGENTS_HOME/mcp/global/cursor.json" ]; then
    ln -f "$AGENTS_HOME/mcp/global/cursor.json" "$repo_path/.cursor/mcp.json" 2>/dev/null || true
  fi
}

# Create .cursorignore link (HARD LINK)
cursor_create_ignore_link() {
  local project="$1"
  local repo_path="$2"

  # Project-specific ignore file takes priority
  if [ -f "$AGENTS_HOME/settings/$project/cursorignore" ]; then
    ln -f "$AGENTS_HOME/settings/$project/cursorignore" "$repo_path/.cursorignore" 2>/dev/null || true
    return 0
  fi

  # Fall back to global ignore file
  if [ -f "$AGENTS_HOME/settings/global/cursorignore" ]; then
    ln -f "$AGENTS_HOME/settings/global/cursorignore" "$repo_path/.cursorignore" 2>/dev/null || true
  fi
}

# Create all Cursor links (rules, settings, MCP, ignore)
cursor_create_all_links() {
  local project="$1"
  local repo_path="$2"

  cursor_create_rule_links "$project" "$repo_path"
  cursor_create_settings_links "$project" "$repo_path"
  cursor_create_mcp_links "$project" "$repo_path"
  cursor_create_ignore_link "$project" "$repo_path"
}
