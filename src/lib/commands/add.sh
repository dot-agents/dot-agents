#!/bin/bash
# dot-agents/lib/commands/add.sh
# Add a project to dot-agents management

cmd_add_help() {
  cat << EOF
${BOLD}dot-agents add${NC} - Add a project to dot-agents management

${BOLD}USAGE${NC}
    dot-agents add <path> [options]

${BOLD}ARGUMENTS${NC}
    <path>            Path to project directory (required)

${BOLD}OPTIONS${NC}
    --name <name>     Override project name (default: directory name)
    --dry-run         Show what would be done without making changes
    --force, -f       Overwrite existing configurations
    --verbose, -v     Show detailed output
    --help, -h        Show this help

${BOLD}DESCRIPTION${NC}
    Registers a project with dot-agents and sets up configuration links.
    Existing config files are backed up before being replaced.

    Creates in ~/.agents/:
    - rules/<project>/         Project-specific rules
    - settings/<project>/      Project settings
    - mcp/<project>/           Project MCP configs

    Links created in project directory:

    ${BOLD}Cursor${NC} (uses HARD LINKS - required by IDE):
    - .cursor/rules/           Global and project rules
    - .cursor/settings.json    IDE settings
    - .cursor/mcp.json         MCP server configs
    - .cursorignore            Files to ignore

    ${BOLD}Claude Code${NC} (uses SYMLINKS):
    - CLAUDE.md                Project instructions
    - .claude/settings.local.json  Project settings
    - .mcp.json                MCP server configs

    ${BOLD}Codex CLI${NC} (uses SYMLINKS):
    - AGENTS.md                Project instructions

    ${BOLD}OpenCode${NC} (uses SYMLINKS):
    - .opencode/               Config directory

${BOLD}EXAMPLES${NC}
    dot-agents add ~/Github/myproject
    dot-agents add . --name my-api
    dot-agents add ~/work/app --dry-run

EOF
}

cmd_add() {
  # Parse flags
  local project_name=""
  local project_path=""

  REMAINING_ARGS=()
  while [[ $# -gt 0 ]]; do
    case $1 in
      --name)
        project_name="$2"
        shift 2
        ;;
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      --force|-f)
        FORCE=true
        shift
        ;;
      --yes|-y)
        YES=true
        shift
        ;;
      --verbose|-v)
        VERBOSE=true
        shift
        ;;
      --help|-h)
        cmd_add_help
        return 0
        ;;
      -*)
        log_error "Unknown option: $1"
        return 1
        ;;
      *)
        REMAINING_ARGS+=("$1")
        shift
        ;;
    esac
  done

  # Get project path from remaining args
  if [ ${#REMAINING_ARGS[@]} -eq 0 ]; then
    log_error "Project path required"
    echo ""
    echo "Usage: dot-agents add <path>"
    return 1
  fi

  project_path="${REMAINING_ARGS[0]}"

  # Expand and validate path
  project_path=$(expand_path "$project_path")

  if [ ! -d "$project_path" ]; then
    log_error "Directory not found: $project_path"
    return 1
  fi

  # Derive project name from directory if not specified
  if [ -z "$project_name" ]; then
    project_name=$(basename "$project_path")
  fi

  # Validate project name (alphanumeric, hyphens, underscores)
  if ! [[ "$project_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    log_error "Invalid project name: $project_name"
    log_info "Use --name to specify a valid name (alphanumeric, hyphens, underscores)"
    return 1
  fi

  local display_path="${project_path/#$HOME/~}"

  log_header "dot-agents add"
  echo -e "Adding project: ${BOLD}$project_name${NC}"
  echo -e "Path: ${DIM}$display_path${NC}"

  # Step 1: Scan project
  init_steps 4
  step "Scanning project..."

  # Check if it's a git repository
  if [ -d "$project_path/.git" ]; then
    bullet "ok" "Valid git repository"
  else
    bullet "none" "Not a git repository (optional)"
  fi

  # Check if already registered
  local existing_path
  existing_path=$(config_get_project_path "$project_name")
  if [ -n "$existing_path" ]; then
    if [ "$FORCE" != true ]; then
      bullet "warn" "Already registered at: $existing_path"
      echo ""
      log_info "Use --force to update, or --name to use a different name"
      return 1
    else
      bullet "warn" "Will update existing registration (--force)"
    fi
  else
    bullet "ok" "Not yet registered"
  fi

  # Check for deprecated formats
  local has_deprecated=false
  if cursor_has_deprecated_format "$project_path"; then
    bullet "warn" "Found deprecated .cursorrules file"
    has_deprecated=true
  fi
  if claude_has_deprecated_format "$project_path"; then
    bullet "warn" "Found deprecated .claude.json file"
    has_deprecated=true
  fi

  if [ "$has_deprecated" = true ]; then
    warn_box "Deprecated Formats Found" \
      "After adding this project, run:" \
      "  dot-agents migrate cursorrules $display_path" \
      "  dot-agents migrate claude-json $display_path"
  fi

  # Step 2: Preview what will be created
  step "The following will be created:"

  preview_section "~/.agents/" \
    "rules/$project_name/              (project rules)" \
    "settings/$project_name/           (project settings)" \
    "  └── claude-code.json            (hooks, permissions)" \
    "mcp/$project_name/                (project MCP configs)"

  preview_section "$display_path/" \
    ".cursor/rules/global--*.mdc       (hard links to global rules)" \
    ".cursor/settings.json             (hard link to settings)" \
    ".cursor/mcp.json                  (hard link to MCP config)" \
    ".cursorignore                     (hard link to ignore patterns)" \
    "CLAUDE.md                         (symlink to rules)" \
    ".claude/settings.local.json       (symlink to settings)" \
    ".mcp.json                         (symlink to MCP config)" \
    "AGENTS.md                         (symlink to rules)" \
    ".opencode/                        (symlinks to configs)"

  info_box "About Link Types" \
    "Cursor uses HARD LINKS (required by IDE)." \
    "Other agents use symlinks for flexibility."

  # Check for existing files that would be replaced (root-level only)
  check_existing_config_files "$project_path"
  local existing_files=()
  [ ${#_CHECK_EXISTING_FILES[@]} -gt 0 ] && existing_files=("${_CHECK_EXISTING_FILES[@]}")

  # Exhaustively scan for all AI config files in the repo
  scan_existing_ai_configs "$project_path"
  local all_ai_configs=()
  [ ${#_SCAN_AI_CONFIGS[@]} -gt 0 ] && all_ai_configs=("${_SCAN_AI_CONFIGS[@]}")

  # Separate files that will be replaced vs. discovered elsewhere
  local discovered_elsewhere=()
  if [ ${#all_ai_configs[@]} -gt 0 ]; then
    for config in "${all_ai_configs[@]}"; do
      local is_root_file=false
      if [ ${#existing_files[@]} -gt 0 ]; then
        for root_file in "${existing_files[@]}"; do
          if [ "$config" = "$root_file" ]; then
            is_root_file=true
            break
          fi
        done
      fi
      if [ "$is_root_file" = false ]; then
        discovered_elsewhere+=("$config")
      fi
    done
  fi

  # Show files that will be replaced
  if [ ${#existing_files[@]} -gt 0 ]; then
    echo ""
    log_section "Files to Replace"
    echo -e "  ${YELLOW}These root-level files will be backed up and replaced with links:${NC}"
    for file in "${existing_files[@]}"; do
      local display_file="${file#$project_path/}"
      local file_type="file"
      [ -L "$file" ] && file_type="symlink"
      echo -e "  ${YELLOW}!${NC} $display_file ${DIM}($file_type)${NC}"
    done

    if [ "$FORCE" != true ]; then
      echo ""
      echo -e "  ${DIM}Backups will be created as *.dot-agents-backup${NC}"
    fi
  fi

  # Show discovered configs elsewhere in the repo (informational)
  if [ ${#discovered_elsewhere[@]} -gt 0 ]; then
    echo ""
    log_section "Other AI Configs Discovered"
    echo -e "  ${CYAN}Found AI agent configs elsewhere in the repo (not replaced):${NC}"
    local shown=0
    for file in "${discovered_elsewhere[@]}"; do
      if [ $shown -lt 10 ]; then
        local display_file="${file#$project_path/}"
        echo -e "  ${CYAN}○${NC} $display_file"
        ((shown++))
      fi
    done
    if [ ${#discovered_elsewhere[@]} -gt 10 ]; then
      echo -e "  ${DIM}... and $((${#discovered_elsewhere[@]} - 10)) more${NC}"
    fi
    echo ""
    echo -e "  ${DIM}Consider migrating these to ~/.agents/ for centralized management.${NC}"
  fi

  # Handle dry-run mode
  if [ "$DRY_RUN" = true ]; then
    echo ""
    log_info "DRY RUN - no changes made"
    return 0
  fi

  # Confirm before proceeding
  local confirm_msg="Proceed?"
  if [ ${#existing_files[@]} -gt 0 ]; then
    confirm_msg="Proceed? (${#existing_files[@]} file(s) will be backed up and replaced)"
  fi

  if ! confirm_action "$confirm_msg"; then
    log_info "Add cancelled."
    return 0
  fi

  # Backup existing files before replacing
  if [ ${#existing_files[@]} -gt 0 ]; then
    for file in "${existing_files[@]}"; do
      if [ -e "$file" ] && [ ! -L "$file" ]; then
        mv "$file" "$file.dot-agents-backup"
      elif [ -L "$file" ]; then
        rm "$file"  # Remove existing symlinks without backup
      fi
    done
    bullet "ok" "Backed up ${#existing_files[@]} existing file(s)"
  fi

  # Step 3: Create project structure
  step "Creating project structure..."
  create_project_dirs_silent "$project_name"
  bullet "ok" "Created ~/.agents/ directories"

  # Copy project settings template if it doesn't exist
  local templates_dir="$SHARE_DIR/templates/standard"
  local project_settings="$AGENTS_HOME/settings/$project_name/claude-code.json"
  if [ ! -f "$project_settings" ]; then
    cp "$templates_dir/settings/project/claude-code.json" "$project_settings" 2>/dev/null || true
    bullet "ok" "Created project settings template"
  fi

  # Step 4: Link to project
  step "Linking to project..."

  # Cursor: .cursor/ with HARD LINKS (rules, settings, MCP, ignore)
  cursor_create_all_links "$project_name" "$project_path"
  bullet "ok" ".cursor/ configs (hard links)"

  # Claude Code: CLAUDE.md and settings symlinks
  claude_create_links "$project_name" "$project_path"
  bullet "ok" "Claude Code links (symlinks)"

  # Codex: AGENTS.md symlink
  codex_create_links "$project_name" "$project_path"
  bullet "ok" "Codex links (symlinks)"

  # OpenCode: .opencode/ symlinks
  opencode_create_links "$project_name" "$project_path"
  bullet "ok" "OpenCode links (symlinks)"

  # Register in config.json
  config_add_project "$project_name" "$project_path"
  bullet "ok" "Registered in config.json"

  # Build next steps based on context
  local next_steps=()
  next_steps+=("Add project rules: edit ~/.agents/rules/$project_name/rules.md")
  if [ "$has_deprecated" = true ]; then
    next_steps+=("Migrate deprecated formats: dot-agents migrate detect")
  fi
  next_steps+=("Check applied configs: dot-agents audit $project_name")

  success_with_next_steps "Project '$project_name' added successfully!" "${next_steps[@]}"

  show_test_commands \
    "dot-agents status" \
    "ls -la $display_path/.cursor/rules/"
}

# Create project directories in ~/.agents/ (silent version for bulk)
create_project_dirs_silent() {
  local project="$1"
  local agents_home="$AGENTS_HOME"

  mkdir -p "$agents_home/rules/$project"
  mkdir -p "$agents_home/settings/$project"
  mkdir -p "$agents_home/mcp/$project"
  mkdir -p "$agents_home/commands/$project"
}

# Create project directories in ~/.agents/ (verbose version)
create_project_dirs() {
  local project="$1"
  local agents_home="$AGENTS_HOME"

  local dirs=(
    "$agents_home/rules/$project"
    "$agents_home/settings/$project"
    "$agents_home/mcp/$project"
    "$agents_home/commands/$project"
  )

  for dir in "${dirs[@]}"; do
    local display_dir="${dir/#$HOME/~}"
    if [ -d "$dir" ]; then
      [ "$VERBOSE" = true ] && log_skip "$display_dir/ (exists)"
    elif [ "$DRY_RUN" = true ]; then
      log_dry "mkdir $display_dir/"
    else
      mkdir -p "$dir"
      log_create "$display_dir/"
    fi
  done
}

# Set up symlinks and hard links in the project directory
setup_project_links() {
  local project="$1"
  local repo="$2"

  # Check for deprecated formats and warn
  check_deprecated_formats "$repo"

  # Use platform modules for linking (sourced via core.sh)
  if [ "$DRY_RUN" = true ]; then
    log_dry "Create Cursor hard links in .cursor/ (rules, settings, MCP, ignore)"
    log_dry "Create Claude Code symlinks (CLAUDE.md, .claude/, .mcp.json)"
    log_dry "Create Codex symlinks (AGENTS.md, .codex/)"
    log_dry "Create OpenCode symlinks (.opencode/)"
  else
    # Cursor: .cursor/ with HARD LINKS (Cursor doesn't follow symlinks)
    cursor_create_all_links "$project" "$repo"
    log_create ".cursor/ configs (hard links)"

    # Claude Code: CLAUDE.md and settings symlinks
    claude_create_links "$project" "$repo"
    log_create "Claude Code links (symlinks)"

    # Codex: AGENTS.md symlink
    codex_create_links "$project" "$repo"
    log_create "Codex links (symlinks)"

    # OpenCode: .opencode/ symlinks
    opencode_create_links "$project" "$repo"
    log_create "OpenCode links (symlinks)"
  fi
}

# Check for deprecated config formats and warn
check_deprecated_formats() {
  local repo="$1"
  local found_deprecated=false

  if cursor_has_deprecated_format "$repo"; then
    log_warn "Found deprecated .cursorrules file"
    log_info "  → Run: dot-agents migrate cursorrules $repo"
    found_deprecated=true
  fi

  if claude_has_deprecated_format "$repo"; then
    log_warn "Found deprecated .claude.json file"
    log_info "  → Run: dot-agents migrate claude-json $repo"
    found_deprecated=true
  fi

  if [ "$found_deprecated" = true ]; then
    echo ""
  fi
}

# Legacy functions removed - now using platform modules:
#   cursor_create_rule_links() from platforms/cursor.sh
#   claude_create_links() from platforms/claude-code.sh
#   codex_create_links() from platforms/codex.sh
#   opencode_create_links() from platforms/opencode.sh

# Check for existing config files that would be replaced by linking
# Sets global _CHECK_EXISTING_FILES array with results
# Usage: check_existing_config_files "/path/to/project"
check_existing_config_files() {
  local project_path="$1"
  _CHECK_EXISTING_FILES=()

  # Root-level files that would be directly replaced
  local root_files=(
    "$project_path/.cursor/rules"
    "$project_path/.cursor/settings.json"
    "$project_path/.cursor/mcp.json"
    "$project_path/.cursorignore"
    "$project_path/CLAUDE.md"
    "$project_path/.claude/settings.local.json"
    "$project_path/.mcp.json"
    "$project_path/AGENTS.md"
    "$project_path/.codex/instructions.md"
    "$project_path/.opencode/instructions.md"
    "$project_path/.opencode/config.json"
  )

  for file in "${root_files[@]}"; do
    if [ -e "$file" ] || [ -L "$file" ]; then
      if [ -d "$file" ]; then
        # Check for files inside directories
        for subfile in "$file"/*; do
          [ -e "$subfile" ] && _CHECK_EXISTING_FILES+=("$subfile")
        done
      else
        _CHECK_EXISTING_FILES+=("$file")
      fi
    fi
  done
}

# Exhaustively scan for AI agent config files throughout the repo
# Sets global _SCAN_AI_CONFIGS array with results
# Usage: scan_existing_ai_configs "/path/to/project"
scan_existing_ai_configs() {
  local project_path="$1"
  _SCAN_AI_CONFIGS=()

  # Use find to locate files, excluding common directories
  local exclude_dirs=".git node_modules vendor dist build __pycache__ .venv venv"
  local exclude_args=""
  for dir in $exclude_dirs; do
    exclude_args="$exclude_args -path '*/$dir/*' -prune -o"
  done

  # File patterns to look for (these are AI agent config files)
  local patterns=(
    # Cursor ecosystem
    ".cursorrules"
    ".cursor/rules/*.mdc"
    ".cursor/rules/*.md"
    ".cursor/settings.json"
    ".cursor/mcp.json"
    ".cursorignore"
    # Claude Code ecosystem
    "CLAUDE.md"
    ".claude/settings.json"
    ".claude/settings.local.json"
    ".claude.json"
    ".mcp.json"
    # Codex ecosystem
    "AGENTS.md"
    ".codex/instructions.md"
    ".codex/config.json"
    "codex.md"
    # OpenCode ecosystem
    ".opencode/instructions.md"
    ".opencode/config.json"
    "OPENCODE.md"
    # Aider
    ".aider*"
    "aider.conf*"
    # Windsurf/Continue
    ".continue/*"
    ".windsurfrules"
    # GitHub Copilot
    ".github/copilot-instructions.md"
    "copilot-instructions.md"
    # Generic AI rules
    ".ai-rules"
    ".ai-instructions"
  )

  # Search for each pattern
  for pattern in "${patterns[@]}"; do
    while IFS= read -r -d '' file; do
      _SCAN_AI_CONFIGS+=("$file")
    done < <(find "$project_path" \
      -path '*/.git/*' -prune -o \
      -path '*/node_modules/*' -prune -o \
      -path '*/vendor/*' -prune -o \
      -path '*/dist/*' -prune -o \
      -path '*/build/*' -prune -o \
      -path '*/__pycache__/*' -prune -o \
      -path '*/.venv/*' -prune -o \
      -path '*/venv/*' -prune -o \
      -name "$pattern" -print0 2>/dev/null)
  done

  # Also check for glob patterns that need special handling
  while IFS= read -r -d '' file; do
    _SCAN_AI_CONFIGS+=("$file")
  done < <(find "$project_path" \
    -path '*/.git/*' -prune -o \
    -path '*/node_modules/*' -prune -o \
    -type f \( -name ".aider*" -o -name "aider.conf*" \) -print0 2>/dev/null)
}
