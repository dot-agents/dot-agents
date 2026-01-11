#!/bin/bash
# dot-agents/lib/commands/doctor.sh
# Health check for dot-agents installation

cmd_doctor_help() {
  cat << EOF
${BOLD}dot-agents doctor${NC} - Check health of dot-agents installation

${BOLD}USAGE${NC}
    dot-agents doctor [options]

${BOLD}OPTIONS${NC}
    --json            Output in JSON format
    --verbose, -v     Show detailed diagnostics
    --help, -h        Show this help

${BOLD}DESCRIPTION${NC}
    Runs health checks on your dot-agents installation:
    - Verifies ~/.agents/ structure
    - Checks for required dependencies (jq)
    - Detects installed AI coding agents
    - Validates config.json schema
    - Checks for common issues

${BOLD}EXAMPLES${NC}
    dot-agents doctor           # Run health check
    dot-agents doctor --json    # Output as JSON

EOF
}

cmd_doctor() {
  # Parse flags
  parse_common_flags "$@"
  set -- "${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}"

  # Show help if requested
  if [ "${SHOW_HELP:-false}" = true ]; then
    cmd_doctor_help
    return 0
  fi

  local checks_passed=0
  local checks_warned=0
  local checks_failed=0

  if [ "$JSON_OUTPUT" = true ]; then
    run_doctor_json
  else
    run_doctor_text
  fi
}

run_doctor_text() {
  log_header "dot-agents doctor"
  echo ""

  # Installation conflicts check (first, most critical)
  check_install_conflicts

  # Core checks
  log_section "Core Installation"

  # Check ~/.agents/ exists
  check_text "~/.agents/ directory" \
    "[ -d '$AGENTS_HOME' ]" \
    "Run 'dot-agents init' to create"

  # Check config.json
  check_text "config.json exists" \
    "[ -f '$AGENTS_HOME/config.json' ]" \
    "Run 'dot-agents init' to create"

  # Check config.json is valid JSON
  if [ -f "$AGENTS_HOME/config.json" ]; then
    check_text "config.json is valid JSON" \
      "jq -e '.' '$AGENTS_HOME/config.json' >/dev/null 2>&1" \
      "Fix JSON syntax in config.json"
  fi

  # Check XDG state directory
  check_text "State directory exists" \
    "[ -d '$AGENTS_STATE_DIR' ] || mkdir -p '$AGENTS_STATE_DIR'" \
    ""

  echo ""
  log_section "Dependencies"

  # Check jq
  check_text "jq (JSON processor)" \
    "command -v jq >/dev/null" \
    "Install: brew install jq"

  # Check git
  check_text "git" \
    "command -v git >/dev/null" \
    "Required for sync features"

  echo ""
  log_section "Detected Agents"

  # Use platform modules for detection (sourced via core.sh)
  detect_agent_platform "Cursor" cursor_is_installed cursor_version
  detect_agent_platform "Claude Code" claude_is_installed claude_version
  detect_agent_platform "Codex CLI" codex_is_installed codex_version
  detect_agent_platform "OpenCode" opencode_is_installed opencode_version

  echo ""
  log_section "Global Settings"

  # Check Claude Code global settings status
  local claude_status
  claude_status=$(claude_global_settings_status)
  case "$claude_status" in
    managed)
      echo -e "  ${GREEN}✓${NC} Claude Code: ~/.claude/settings.json ${DIM}(managed by dot-agents)${NC}"
      ((checks_passed++)) || true
      ;;
    unmanaged_file)
      echo -e "  ${YELLOW}○${NC} Claude Code: ~/.claude/settings.json ${DIM}(exists, not managed)${NC}"
      echo -e "      ${DIM}→ To manage: dot-agents link claude-global${NC}"
      ;;
    not_found)
      echo -e "  ${GRAY}○${NC} Claude Code: ~/.claude/settings.json ${DIM}(not found)${NC}"
      ;;
    symlink_other:*)
      local target="${claude_status#symlink_other:}"
      echo -e "  ${YELLOW}○${NC} Claude Code: ~/.claude/settings.json ${DIM}(symlink to $target)${NC}"
      ;;
  esac

  echo ""
  log_section "Hooks Configuration"

  # Check global hooks settings
  local global_settings="$AGENTS_HOME/settings/global/claude-code.json"
  if [ -f "$global_settings" ]; then
    # Validate JSON syntax
    if jq -e '.' "$global_settings" >/dev/null 2>&1; then
      local hook_count=0
      for hook_type in PreToolUse PostToolUse PreRequest PostRequest; do
        local count
        count=$(jq -r ".hooks.$hook_type | length" "$global_settings" 2>/dev/null || echo "0")
        hook_count=$((hook_count + count))
      done

      if [ "$hook_count" -gt 0 ]; then
        echo -e "  ${GREEN}✓${NC} Global hooks: $hook_count hook(s) configured"
        ((checks_passed++)) || true
      else
        echo -e "  ${GRAY}○${NC} Global hooks: none configured"
      fi
    else
      echo -e "  ${RED}✗${NC} Global settings: invalid JSON syntax"
      echo -e "      ${DIM}→ Check ~/.agents/settings/global/claude-code.json${NC}"
      ((checks_failed++)) || true
    fi
  else
    echo -e "  ${YELLOW}○${NC} Global settings: not found"
    echo -e "      ${DIM}→ Run 'dot-agents init' to create${NC}"
  fi

  echo ""
  log_section "Skills"

  # Check global skills (directory-based)
  local global_skills="$AGENTS_HOME/skills/global"
  if [ -d "$global_skills" ]; then
    local skill_count=0
    for skill_dir in "$global_skills"/*/; do
      [ -d "$skill_dir" ] || continue
      [ -f "$skill_dir/SKILL.md" ] && ((skill_count++)) || true
    done

    if [ "$skill_count" -gt 0 ]; then
      echo -e "  ${GREEN}✓${NC} Global skills: $skill_count found"
      ((checks_passed++)) || true
    else
      echo -e "  ${YELLOW}○${NC} Global skills: directory exists but empty"
      echo -e "      ${DIM}→ Run 'dot-agents init --force' to create templates${NC}"
    fi
  else
    echo -e "  ${YELLOW}○${NC} Global skills: not found"
    echo -e "      ${DIM}→ Run 'dot-agents init' to create${NC}"
  fi

  # Check project skills symlinks
  if [ -f "$AGENTS_HOME/config.json" ] && has_jq; then
    local projects
    projects=$(jq -r '.projects | keys[]' "$AGENTS_HOME/config.json" 2>/dev/null)

    for project in $projects; do
      local project_path
      project_path=$(jq -r ".projects[\"$project\"].path" "$AGENTS_HOME/config.json")
      project_path=$(expand_path "$project_path")

      [ -d "$project_path" ] || continue

      local skills_dir="$project_path/.claude/skills"
      if [ -d "$skills_dir" ]; then
        local skill_count=0
        for skill in "$skills_dir"/*/; do
          [ -d "$skill" ] || [ -L "$skill" ] && ((skill_count++)) || true
        done
        if [ "$skill_count" -gt 0 ]; then
          echo -e "  ${GREEN}✓${NC} $project: $skill_count skill(s) linked"
        else
          echo -e "  ${YELLOW}○${NC} $project: .claude/skills/ empty"
          echo -e "      ${DIM}→ dot-agents link${NC}"
        fi
      else
        echo -e "  ${GRAY}○${NC} $project: no .claude/skills/"
      fi
    done
  fi

  echo ""
  log_section "Directory Structure"

  # Check key directories exist
  local dirs=(
    "rules/global"
    "settings/global"
    "mcp/global"
    "skills/global"
    "scripts"
    "local"
  )

  for dir in "${dirs[@]}"; do
    check_text "$dir/" \
      "[ -d '$AGENTS_HOME/$dir' ]" \
      "mkdir -p ~/.agents/$dir"
  done

  # Check for deprecated formats in registered projects
  echo ""
  log_section "Deprecated Formats"

  local deprecated_count=0
  local config_file="$AGENTS_HOME/config.json"

  if [ -f "$config_file" ] && has_jq; then
    local projects
    projects=$(jq -r '.projects | keys[]' "$config_file" 2>/dev/null)

    for project in $projects; do
      local project_path
      project_path=$(jq -r ".projects[\"$project\"].path" "$config_file")
      project_path=$(expand_path "$project_path")

      [ -d "$project_path" ] || continue

      # Use platform modules for deprecated format detection
      if cursor_has_deprecated_format "$project_path"; then
        echo -e "  ${YELLOW}⚠${NC}  ${BOLD}$project${NC}: .cursorrules ${DIM}(deprecated)${NC}"
        echo -e "      ${DIM}→ dot-agents migrate cursorrules $project_path${NC}"
        ((deprecated_count++))
      fi

      if claude_has_deprecated_format "$project_path"; then
        echo -e "  ${YELLOW}⚠${NC}  ${BOLD}$project${NC}: .claude.json ${DIM}(deprecated)${NC}"
        echo -e "      ${DIM}→ dot-agents migrate claude-json $project_path${NC}"
        ((deprecated_count++))
      fi
    done

    if [ $deprecated_count -eq 0 ]; then
      echo -e "  ${GREEN}✓${NC} No deprecated formats found"
    fi
  else
    echo -e "  ${DIM}○${NC} Skipped (no config or jq)"
  fi

  # Summary
  echo ""
  echo "────────────────────────────────────────────────────"
  local total=$((checks_passed + checks_warned + checks_failed))
  echo -e "Checks: ${GREEN}$checks_passed passed${NC}, ${YELLOW}$checks_warned warnings${NC}, ${RED}$checks_failed failed${NC} (total: $total)"

  if [ $deprecated_count -gt 0 ]; then
    echo -e "Deprecated: ${YELLOW}$deprecated_count${NC} format(s) need migration"
  fi

  if [ $checks_failed -gt 0 ]; then
    return 1
  fi
  return 0
}

run_doctor_json() {
  echo "{"
  echo '  "version": "'$DOT_AGENTS_VERSION'",'

  # Core checks
  echo '  "core": {'
  echo -n '    "agents_home": '
  [ -d "$AGENTS_HOME" ] && echo '"ok",' || echo '"missing",'
  echo -n '    "config_json": '
  [ -f "$AGENTS_HOME/config.json" ] && echo '"ok",' || echo '"missing",'
  echo -n '    "config_valid": '
  jq -e '.' "$AGENTS_HOME/config.json" >/dev/null 2>&1 && echo '"ok"' || echo '"invalid"'
  echo '  },'

  # Dependencies
  echo '  "dependencies": {'
  echo -n '    "jq": '
  command -v jq >/dev/null && echo '"installed",' || echo '"missing",'
  echo -n '    "git": '
  command -v git >/dev/null && echo '"installed"' || echo '"missing"'
  echo '  },'

  # Agents - use platform module functions
  echo '  "agents": {'

  echo -n '    "cursor": '
  if cursor_is_installed; then
    local cursor_ver
    cursor_ver=$(cursor_version || echo "unknown")
    echo '{"installed": true, "version": "'"$cursor_ver"'"},'
  else
    echo '{"installed": false},'
  fi

  echo -n '    "claude-code": '
  if claude_is_installed; then
    local claude_ver
    claude_ver=$(claude_version || echo "unknown")
    echo '{"installed": true, "version": "'"$claude_ver"'"},'
  else
    echo '{"installed": false},'
  fi

  echo -n '    "codex": '
  if codex_is_installed; then
    local codex_ver
    codex_ver=$(codex_version || echo "unknown")
    echo '{"installed": true, "version": "'"$codex_ver"'"},'
  else
    echo '{"installed": false},'
  fi

  echo -n '    "opencode": '
  if opencode_is_installed; then
    local opencode_ver
    opencode_ver=$(opencode_version || echo "unknown")
    echo '{"installed": true, "version": "'"$opencode_ver"'"}'
  else
    echo '{"installed": false}'
  fi

  echo '  }'
  echo "}"
}

# Check for conflicting installations
check_install_conflicts() {
  local curl_bin="$HOME/.local/bin/dot-agents"
  local hb_bin=""

  # Find Homebrew binary
  if [ -x "/opt/homebrew/bin/dot-agents" ]; then
    hb_bin="/opt/homebrew/bin/dot-agents"
  elif [ -x "/usr/local/bin/dot-agents" ]; then
    hb_bin="/usr/local/bin/dot-agents"
  fi

  # Check for conflict
  if [ -x "$curl_bin" ] && [ -n "$hb_bin" ] && [ -x "$hb_bin" ]; then
    log_section "Installation Conflict"
    echo -e "  ${RED}✗${NC} Multiple installations detected!"
    echo ""
    echo "    curl:     $curl_bin"
    echo "    homebrew: $hb_bin"
    echo ""

    local active
    active=$(command -v dot-agents 2>/dev/null)
    echo "    Active:   $active"
    echo ""

    if [ "$active" = "$curl_bin" ]; then
      echo -e "    ${YELLOW}⚠${NC}  You're running the curl version, but Homebrew is also installed."
      echo "       Homebrew upgrades won't affect the version you're actually using."
      echo ""
      echo "    To fix, remove the curl installation:"
      echo "      rm $curl_bin"
      echo "      rm -rf ~/.local/lib/dot-agents"
      echo "      rm -rf ~/.local/share/dot-agents"
    else
      echo -e "    ${YELLOW}⚠${NC}  Old curl installation still exists but is not in use."
      echo ""
      echo "    To clean up:"
      echo "      rm $curl_bin"
      echo "      rm -rf ~/.local/lib/dot-agents"
      echo "      rm -rf ~/.local/share/dot-agents"
    fi

    echo ""
    ((checks_warned++)) || true
  fi
}

# Helper: Run a check and output result for text mode
check_text() {
  local name="$1"
  local test_cmd="$2"
  local fix_hint="$3"

  if eval "$test_cmd" 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} $name"
    ((checks_passed++)) || true
  else
    if [ -n "$fix_hint" ]; then
      echo -e "  ${RED}✗${NC} $name"
      echo -e "    ${DIM}→ $fix_hint${NC}"
      ((checks_failed++)) || true
    else
      echo -e "  ${YELLOW}!${NC} $name"
      ((checks_warned++)) || true
    fi
  fi
}

# Helper: Detect an agent using platform module functions
detect_agent_platform() {
  local name="$1"
  local is_installed_func="$2"
  local version_func="$3"

  if $is_installed_func 2>/dev/null; then
    local version
    version=$($version_func 2>/dev/null || echo "unknown")
    echo -e "  ${GREEN}✓${NC} $name ${DIM}($version)${NC}"
    ((checks_passed++)) || true
  else
    echo -e "  ${GRAY}○${NC} $name ${DIM}(not found)${NC}"
  fi
}
