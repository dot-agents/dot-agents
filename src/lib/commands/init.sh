#!/bin/bash
# dot-agents/lib/commands/init.sh
# Initialize ~/.agents/ directory structure

cmd_init_help() {
  cat << EOF
${BOLD}dot-agents init${NC} - Initialize ~/.agents/ directory

${BOLD}USAGE${NC}
    dot-agents init [options]

${BOLD}OPTIONS${NC}
    --dry-run         Show what would be created without making changes
    --force, -f       Overwrite existing files
    --verbose, -v     Show detailed output
    --help, -h        Show this help

${BOLD}DESCRIPTION${NC}
    Creates the ~/.agents/ directory structure with starter templates.
    Safe to run multiple times - existing files are preserved unless --force.

${BOLD}CREATED STRUCTURE${NC}
    ~/.agents/
    ├── config.json           # Main configuration
    ├── README.md             # Documentation
    ├── .gitignore            # Git ignore patterns
    ├── rules/
    │   └── global/           # Global rules for all projects
    │       └── rules.mdc     # Starter rules file
    ├── settings/
    │   └── global/           # Global settings
    ├── mcp/
    │   └── global/           # Global MCP configs
    ├── skills/
    │   └── global/           # Global skills (directory-based)
    │       ├── agent-start/SKILL.md
    │       ├── agent-handoff/SKILL.md
    │       └── self-review/SKILL.md
    ├── scripts/              # Utility scripts
    └── local/                # Machine-specific (gitignored)

${BOLD}EXAMPLES${NC}
    dot-agents init              # Initialize with defaults
    dot-agents init --dry-run    # Preview what would be created
    dot-agents init --force      # Overwrite existing files

EOF
}

cmd_init() {
  # Parse flags
  parse_common_flags "$@"
  set -- "${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}"

  # Show help if requested
  if [ "${SHOW_HELP:-false}" = true ]; then
    cmd_init_help
    return 0
  fi

  local agents_home="$AGENTS_HOME"
  local templates_dir="$SHARE_DIR/templates/standard"

  log_header "dot-agents init"
  show_intro "This will set up the dot-agents configuration directory."

  # Step 1: Check existing installation
  init_steps 3
  step "Checking existing installation..."

  if [ -d "$agents_home" ]; then
    bullet "found" "Existing ~/.agents/ directory found"
    if [ "$FORCE" != true ]; then
      echo ""
      log_info "Use --force to reinitialize (creates backup first)"
      return 0
    else
      bullet "warn" "Will backup and reinitialize (--force)"
    fi
  else
    bullet "none" "No existing ~/.agents/ found"
  fi

  # Step 2: Preview what will be created
  step "The following will be created:"

  preview_changes "Directories:" \
    "~/.agents/                     (main config directory)" \
    "~/.agents/rules/global/        (shared rules for all agents)" \
    "~/.agents/settings/global/     (shared settings)" \
    "~/.agents/mcp/global/          (shared MCP configs)" \
    "~/.agents/skills/global/       (shared skills, directory-based)" \
    "~/.agents/scripts/             (utility scripts)" \
    "~/.agents/local/               (machine-specific, gitignored)"

  preview_changes "Files:" \
    "~/.agents/config.json          (project registry)" \
    "~/.agents/README.md            (documentation)" \
    "~/.agents/.gitignore           (git ignore patterns)" \
    "~/.agents/rules/global/rules.mdc (starter rules)" \
    "~/.agents/settings/global/claude-code.json (hooks, permissions)" \
    "~/.agents/skills/global/agent-start/SKILL.md (session start)" \
    "~/.agents/skills/global/agent-handoff/SKILL.md (session handoff)" \
    "~/.agents/skills/global/self-review/SKILL.md (pre-commit checklist)"

  info_box "Tip" \
    "This directory should be version controlled." \
    "Run 'dot-agents sync init' after to set up git."

  # Handle dry-run mode
  if [ "$DRY_RUN" = true ]; then
    echo ""
    log_info "DRY RUN - no changes made"
    return 0
  fi

  # Confirm before proceeding
  if ! confirm_action "Proceed with initialization?"; then
    log_info "Initialization cancelled."
    return 0
  fi

  # Step 3: Create everything
  step "Creating directories and files..."

  # Backup if force mode and exists
  if [ -d "$agents_home" ] && [ "$FORCE" = true ]; then
    backup_existing "$agents_home"
  fi

  # Create directories
  local dirs=(
    "$agents_home"
    "$agents_home/rules/global"
    "$agents_home/settings/global"
    "$agents_home/mcp/global"
    "$agents_home/skills/global/agent-start"
    "$agents_home/skills/global/agent-handoff"
    "$agents_home/skills/global/self-review"
    "$agents_home/scripts"
    "$agents_home/local"
  )

  for dir in "${dirs[@]}"; do
    create_dir_silent "$dir"
  done
  bullet "ok" "Created directory structure"

  # Copy template files
  create_file_from_template_silent "$templates_dir/config.json" "$agents_home/config.json"
  create_file_from_template_silent "$templates_dir/README.md" "$agents_home/README.md"
  create_file_from_template_silent "$templates_dir/.gitignore" "$agents_home/.gitignore"
  create_file_from_template_silent "$templates_dir/rules/global/rules.mdc" "$agents_home/rules/global/rules.mdc"
  create_file_from_template_silent "$templates_dir/settings/global/claude-code.json" "$agents_home/settings/global/claude-code.json"
  bullet "ok" "Created template files"

  # Copy skill templates (directory-based)
  create_file_from_template_silent "$templates_dir/skills/global/agent-start/SKILL.md" "$agents_home/skills/global/agent-start/SKILL.md"
  create_file_from_template_silent "$templates_dir/skills/global/agent-handoff/SKILL.md" "$agents_home/skills/global/agent-handoff/SKILL.md"
  create_file_from_template_silent "$templates_dir/skills/global/self-review/SKILL.md" "$agents_home/skills/global/self-review/SKILL.md"
  bullet "ok" "Created skill templates"

  # Create XDG state directory
  mkdir -p "$AGENTS_STATE_DIR"
  bullet "ok" "Created state directory"

  success_with_next_steps "Initialization complete!" \
    "Add your first project: dot-agents add ~/path/to/project" \
    "Set up git sync: dot-agents sync init" \
    "Check health: dot-agents doctor"

  show_test_commands \
    "dot-agents status"
}

# Silent version of create_dir for bulk operations
create_dir_silent() {
  local dir="$1"
  [ -d "$dir" ] || mkdir -p "$dir"
}

# Silent version of create_file_from_template for bulk operations
create_file_from_template_silent() {
  local template="$1"
  local target="$2"

  if [ -f "$target" ] && [ "$FORCE" != true ]; then
    return 0  # Skip existing files unless force
  fi

  if [ -f "$template" ]; then
    mkdir -p "$(dirname "$target")"
    cp "$template" "$target"
  fi
}

# Helper: Backup existing ~/.agents/ before force-reinitialize
backup_existing() {
  local agents_home="$1"
  local backup_dir="$AGENTS_STATE_DIR/backups"
  local timestamp=$(date +%Y%m%d-%H%M%S)
  local backup_path="$backup_dir/agents-backup-$timestamp"

  log_section "Creating backup"

  if [ "$DRY_RUN" = true ]; then
    log_dry "backup ~/.agents/ → $backup_path/"
    return 0
  fi

  # Ensure backup directory exists
  mkdir -p "$backup_dir"

  # Copy current ~/.agents/ to backup
  if cp -a "$agents_home" "$backup_path"; then
    log_success "Backup created: $backup_path"
  else
    log_error "Failed to create backup"
    die "Aborting init to protect your data. Please backup ~/.agents/ manually."
  fi
}

# Helper: Create directory
create_dir() {
  local dir="$1"
  local display_dir="${dir/#$HOME/~}"

  if [ -d "$dir" ]; then
    [ "$VERBOSE" = true ] && log_skip "$display_dir/ (exists)"
    return 0
  fi

  if [ "$DRY_RUN" = true ]; then
    log_dry "mkdir $display_dir/"
  else
    mkdir -p "$dir"
    log_create "$display_dir/"
  fi
}

# Helper: Create file from template
create_file_from_template() {
  local template="$1"
  local target="$2"
  local display_target="${target/#$HOME/~}"

  # Check if target exists
  if [ -f "$target" ] && [ "$FORCE" != true ]; then
    [ "$VERBOSE" = true ] && log_skip "$display_target (exists)"
    return 0
  fi

  # Check if template exists
  if [ ! -f "$template" ]; then
    log_warn "Template not found: $template"
    return 1
  fi

  if [ "$DRY_RUN" = true ]; then
    log_dry "create $display_target"
  else
    # Ensure parent directory exists
    mkdir -p "$(dirname "$target")"
    cp "$template" "$target"
    log_create "$display_target"
  fi
}
