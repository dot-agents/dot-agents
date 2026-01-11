#!/bin/bash
# dot-agents/lib/commands/link.sh
# Set up symlinks between ~/.agents/ and platform-specific locations

cmd_link_help() {
  cat << EOF
${BOLD}dot-agents link${NC} - Set up symlinks to platform locations

${BOLD}USAGE${NC}
    dot-agents link [options]

${BOLD}OPTIONS${NC}
    --global          Link global skills to platform global locations
    --platform <name> Only link to specific platform (claude, cursor, codex)
    --dry-run         Show what would be done without making changes
    --force, -f       Overwrite existing symlinks
    --verbose, -v     Show detailed output
    --help, -h        Show this help

${BOLD}DESCRIPTION${NC}
    Creates symlinks from ~/.agents/skills/ to platform-specific locations:

    Global linking (--global):
    - Claude Code:  ~/.claude/skills/{name}/     → ~/.agents/skills/global/{name}/
    - Cursor:       ~/.cursor/commands/{name}.md → ~/.agents/skills/global/{name}/SKILL.md
    - Codex CLI:    ~/.codex/skills/{name}/      → ~/.agents/skills/global/{name}/

    Per-project linking is done automatically by 'dot-agents add'.

${BOLD}EXAMPLES${NC}
    dot-agents link --global                    # Link all global skills
    dot-agents link --global --platform claude  # Claude Code only
    dot-agents link --global --dry-run          # Preview what would be linked

EOF
}

cmd_link() {
  # Parse flags
  local do_global=false
  local platform=""

  parse_common_flags "$@"
  set -- "${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}"

  # Show help if requested
  if [ "${SHOW_HELP:-false}" = true ]; then
    cmd_link_help
    return 0
  fi

  # Parse additional flags
  while [[ $# -gt 0 ]]; do
    case $1 in
      --global)
        do_global=true
        shift
        ;;
      --platform)
        platform="$2"
        shift 2
        ;;
      -*)
        log_error "Unknown option: $1"
        return 1
        ;;
      *)
        log_error "Unexpected argument: $1"
        return 1
        ;;
    esac
  done

  if [ "$do_global" = true ]; then
    link_global "$platform"
  else
    cmd_link_help
    return 1
  fi
}

# Link global skills to platform global locations
link_global() {
  local platform="$1"
  local skills_dir="$AGENTS_HOME/skills/global"

  log_header "dot-agents link --global"

  if [ ! -d "$skills_dir" ]; then
    log_error "No global skills found at ~/.agents/skills/global/"
    echo "Run 'dot-agents init' first to create skill templates."
    return 1
  fi

  if [ "$DRY_RUN" = true ]; then
    log_warn "DRY RUN - no changes will be made"
    echo ""
  fi

  # Count skills
  local skill_count=0
  for skill_dir in "$skills_dir"/*/; do
    [ -d "$skill_dir" ] || continue
    [ -f "$skill_dir/SKILL.md" ] || continue
    ((skill_count++))
  done

  if [ "$skill_count" -eq 0 ]; then
    echo -e "${DIM}No skills found in ~/.agents/skills/global/${NC}"
    return 0
  fi

  echo "Found $skill_count global skill(s) to link."
  echo ""

  # Link to each platform
  if [ -z "$platform" ] || [ "$platform" = "claude" ]; then
    link_global_claude "$skills_dir"
  fi

  if [ -z "$platform" ] || [ "$platform" = "cursor" ]; then
    link_global_cursor "$skills_dir"
  fi

  if [ -z "$platform" ] || [ "$platform" = "codex" ]; then
    link_global_codex "$skills_dir"
  fi

  echo ""
  if [ "$DRY_RUN" != true ]; then
    log_success "Global linking complete!"
    echo ""
    echo "Skills are now available globally in supported platforms."
  fi
}

# Link global skills to ~/.claude/skills/
link_global_claude() {
  local skills_dir="$1"
  local target_dir="$HOME/.claude/skills"

  log_section "Claude Code (~/.claude/skills/)"

  if ! claude_is_installed 2>/dev/null; then
    echo -e "  ${DIM}○ Claude Code not installed, skipping${NC}"
    return 0
  fi

  if [ "$DRY_RUN" != true ]; then
    mkdir -p "$target_dir"
  fi

  for skill_dir in "$skills_dir"/*/; do
    [ -d "$skill_dir" ] || continue
    [ -f "$skill_dir/SKILL.md" ] || continue

    local name
    name=$(basename "$skill_dir")
    local link_path="$target_dir/$name"

    if [ "$DRY_RUN" = true ]; then
      echo -e "  ${DIM}→${NC} $name/ → $skill_dir"
    else
      # Remove existing link/directory if force
      if [ -e "$link_path" ] || [ -L "$link_path" ]; then
        if [ "$FORCE" = true ]; then
          rm -rf "$link_path"
        else
          echo -e "  ${YELLOW}○${NC} $name (exists, use --force to overwrite)"
          continue
        fi
      fi

      ln -s "$skill_dir" "$link_path"
      echo -e "  ${GREEN}✓${NC} $name"
    fi
  done
}

# Link global skills to ~/.cursor/commands/
link_global_cursor() {
  local skills_dir="$1"
  local target_dir="$HOME/.cursor/commands"

  log_section "Cursor (~/.cursor/commands/)"

  if ! cursor_is_installed 2>/dev/null; then
    echo -e "  ${DIM}○ Cursor not installed, skipping${NC}"
    return 0
  fi

  if [ "$DRY_RUN" != true ]; then
    mkdir -p "$target_dir"
  fi

  for skill_dir in "$skills_dir"/*/; do
    [ -d "$skill_dir" ] || continue
    [ -f "$skill_dir/SKILL.md" ] || continue

    local name
    name=$(basename "$skill_dir")
    local skill_file="$skill_dir/SKILL.md"
    local link_path="$target_dir/$name.md"

    if [ "$DRY_RUN" = true ]; then
      echo -e "  ${DIM}→${NC} $name.md → $skill_file"
    else
      # Remove existing link/file if force
      if [ -e "$link_path" ] || [ -L "$link_path" ]; then
        if [ "$FORCE" = true ]; then
          rm -f "$link_path"
        else
          echo -e "  ${YELLOW}○${NC} $name.md (exists, use --force to overwrite)"
          continue
        fi
      fi

      # Symlink to SKILL.md directly (Cursor uses flat files)
      ln -s "$skill_file" "$link_path"
      echo -e "  ${GREEN}✓${NC} $name.md"
    fi
  done
}

# Link global skills to ~/.codex/skills/
link_global_codex() {
  local skills_dir="$1"
  local target_dir="$HOME/.codex/skills"

  log_section "Codex CLI (~/.codex/skills/)"

  if ! codex_is_installed 2>/dev/null; then
    echo -e "  ${DIM}○ Codex CLI not installed, skipping${NC}"
    return 0
  fi

  if [ "$DRY_RUN" != true ]; then
    mkdir -p "$target_dir"
  fi

  for skill_dir in "$skills_dir"/*/; do
    [ -d "$skill_dir" ] || continue
    [ -f "$skill_dir/SKILL.md" ] || continue

    local name
    name=$(basename "$skill_dir")
    local link_path="$target_dir/$name"

    if [ "$DRY_RUN" = true ]; then
      echo -e "  ${DIM}→${NC} $name/ → $skill_dir"
    else
      # Remove existing link/directory if force
      if [ -e "$link_path" ] || [ -L "$link_path" ]; then
        if [ "$FORCE" = true ]; then
          rm -rf "$link_path"
        else
          echo -e "  ${YELLOW}○${NC} $name (exists, use --force to overwrite)"
          continue
        fi
      fi

      ln -s "$skill_dir" "$link_path"
      echo -e "  ${GREEN}✓${NC} $name"
    fi
  done
}
