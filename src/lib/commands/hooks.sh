#!/bin/bash
# dot-agents/lib/commands/hooks.sh
# Manage Claude Code hooks configuration

cmd_hooks_help() {
  cat << EOF
${BOLD}dot-agents hooks${NC} - Manage Claude Code hooks

${BOLD}USAGE${NC}
    dot-agents hooks [subcommand] [options]

${BOLD}SUBCOMMANDS${NC}
    list                  List all hooks (default)
    add <type>            Add a hook
    remove <type> <index> Remove a hook by index
    edit                  Open hooks settings in editor
    examples              Show common hook examples

${BOLD}OPTIONS${NC}
    --project, -p <name>  Target specific project (default: current directory)
    --global, -g          Target global hooks only
    --json                Output in JSON format
    --help, -h            Show this help

${BOLD}HOOK TYPES${NC}
    PreToolUse            Before executing any tool (Bash, Edit, Read, etc.)
    PostToolUse           After tool execution completes
    PreRequest            Before sending request to Claude
    PostRequest           After receiving response

${BOLD}ADD OPTIONS${NC}
    --command, -c <cmd>   Shell command to run (required)
    --matcher, -m <pat>   Tool pattern to match (default: "*")

${BOLD}ENVIRONMENT VARIABLES${NC}
    Hooks receive these environment variables:
    \$TOOL_INPUT          The tool's input (for tool hooks)
    \$TOOL_OUTPUT         The tool's output (PostToolUse only)
    \$SESSION_ID          Current Claude session ID

${BOLD}EXAMPLES${NC}
    dot-agents hooks                          # List all hooks
    dot-agents hooks --global                 # List global hooks only
    dot-agents hooks --project myapp          # List project hooks

    dot-agents hooks add PreToolUse -m "Bash" -c "echo \\\$TOOL_INPUT >> log.txt"
    dot-agents hooks remove PreToolUse 0      # Remove first PreToolUse hook
    dot-agents hooks edit                     # Edit in \$EDITOR
    dot-agents hooks examples                 # Show example hooks

EOF
}

cmd_hooks() {
  # Parse flags
  local subcommand="list"
  local project_name=""
  local global_only=false
  local hook_type=""
  local hook_command=""
  local hook_matcher="*"
  local hook_index=""

  REMAINING_ARGS=()
  while [[ $# -gt 0 ]]; do
    case $1 in
      --project|-p)
        project_name="$2"
        shift 2
        ;;
      --global|-g)
        global_only=true
        shift
        ;;
      --command|-c)
        hook_command="$2"
        shift 2
        ;;
      --matcher|-m)
        hook_matcher="$2"
        shift 2
        ;;
      --json)
        JSON_OUTPUT=true
        shift
        ;;
      --help|-h)
        cmd_hooks_help
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

  # Parse subcommand and arguments
  if [ ${#REMAINING_ARGS[@]} -gt 0 ]; then
    subcommand="${REMAINING_ARGS[0]}"
    if [ ${#REMAINING_ARGS[@]} -gt 1 ]; then
      hook_type="${REMAINING_ARGS[1]}"
    fi
    if [ ${#REMAINING_ARGS[@]} -gt 2 ]; then
      hook_index="${REMAINING_ARGS[2]}"
    fi
  fi

  # Determine project context if not explicitly set
  if [ -z "$project_name" ] && [ "$global_only" = false ]; then
    project_name=$(detect_current_project)
  fi

  case "$subcommand" in
    list)
      hooks_list "$project_name" "$global_only"
      ;;
    add)
      if [ -z "$hook_type" ]; then
        log_error "Hook type required. Valid types: PreToolUse, PostToolUse, PreRequest, PostRequest"
        return 1
      fi
      if [ -z "$hook_command" ]; then
        log_error "Command required. Use --command or -c"
        return 1
      fi
      hooks_add "$project_name" "$global_only" "$hook_type" "$hook_matcher" "$hook_command"
      ;;
    remove)
      if [ -z "$hook_type" ]; then
        log_error "Hook type required"
        return 1
      fi
      if [ -z "$hook_index" ]; then
        log_error "Hook index required"
        return 1
      fi
      hooks_remove "$project_name" "$global_only" "$hook_type" "$hook_index"
      ;;
    edit)
      hooks_edit "$project_name" "$global_only"
      ;;
    examples)
      hooks_examples
      ;;
    *)
      log_error "Unknown subcommand: $subcommand"
      cmd_hooks_help
      return 1
      ;;
  esac
}

# List hooks for global and/or project
hooks_list() {
  local project_name="$1"
  local global_only="$2"

  local global_settings="$AGENTS_HOME/settings/global/claude-code.json"
  local project_settings=""

  if [ -n "$project_name" ]; then
    project_settings="$AGENTS_HOME/settings/$project_name/claude-code.json"
  fi

  if [ "$JSON_OUTPUT" = true ]; then
    hooks_list_json "$global_settings" "$project_settings" "$project_name"
    return
  fi

  log_header "dot-agents hooks"

  if [ -n "$project_name" ] && [ "$global_only" = false ]; then
    echo -e "Project: ${BOLD}$project_name${NC}"
  fi
  echo ""

  # Global hooks
  log_section "Global Hooks"
  echo -e "  ${DIM}~/.agents/settings/global/claude-code.json${NC}"
  echo ""

  if [ -f "$global_settings" ]; then
    hooks_display_from_file "$global_settings" "  "
  else
    echo -e "  ${DIM}No global settings file found${NC}"
    echo -e "  ${DIM}Run 'dot-agents init' to create one${NC}"
  fi

  # Project hooks
  if [ -n "$project_name" ] && [ "$global_only" = false ]; then
    echo ""
    log_section "Project Hooks ($project_name)"
    echo -e "  ${DIM}~/.agents/settings/$project_name/claude-code.json${NC}"
    echo ""

    if [ -f "$project_settings" ]; then
      hooks_display_from_file "$project_settings" "  "
    else
      echo -e "  ${DIM}No project settings file found${NC}"
      echo -e "  ${DIM}Run 'dot-agents add <path>' to create one${NC}"
    fi
  fi

  echo ""
  echo -e "${DIM}Tip: Use 'dot-agents hooks add <type> -m \"pattern\" -c \"command\"' to add hooks${NC}"
}

# Display hooks from a settings file
hooks_display_from_file() {
  local file="$1"
  local indent="$2"

  local hook_types=("PreToolUse" "PostToolUse" "PreRequest" "PostRequest")
  local has_hooks=false

  for hook_type in "${hook_types[@]}"; do
    local hooks
    hooks=$(jq -r ".hooks.$hook_type // []" "$file" 2>/dev/null)
    local count
    count=$(echo "$hooks" | jq 'length' 2>/dev/null || echo "0")

    if [ "$count" -gt 0 ]; then
      has_hooks=true
      echo -e "${indent}${BOLD}$hook_type:${NC}"

      local i=0
      while [ $i -lt "$count" ]; do
        local matcher
        local command
        matcher=$(echo "$hooks" | jq -r ".[$i].matcher // \"*\"" 2>/dev/null)
        command=$(echo "$hooks" | jq -r ".[$i].hooks[0].command // \"(no command)\"" 2>/dev/null)

        # Truncate long commands
        if [ ${#command} -gt 50 ]; then
          command="${command:0:47}..."
        fi

        echo -e "${indent}  ${CYAN}[$i]${NC} ${YELLOW}$matcher${NC} ${DIM}→${NC} $command"
        ((i++))
      done
      echo ""
    fi
  done

  if [ "$has_hooks" = false ]; then
    echo -e "${indent}${DIM}No hooks configured${NC}"
  fi
}

# Output hooks as JSON
hooks_list_json() {
  local global_settings="$1"
  local project_settings="$2"
  local project_name="$3"

  echo "{"
  echo "  \"global\": {"

  if [ -f "$global_settings" ]; then
    local global_hooks
    global_hooks=$(jq '.hooks // {}' "$global_settings" 2>/dev/null || echo "{}")
    echo "    \"file\": \"$global_settings\","
    echo "    \"hooks\": $global_hooks"
  else
    echo "    \"file\": null,"
    echo "    \"hooks\": {}"
  fi

  echo "  },"
  echo "  \"project\": {"

  if [ -n "$project_name" ] && [ -f "$project_settings" ]; then
    local project_hooks
    project_hooks=$(jq '.hooks // {}' "$project_settings" 2>/dev/null || echo "{}")
    echo "    \"name\": \"$project_name\","
    echo "    \"file\": \"$project_settings\","
    echo "    \"hooks\": $project_hooks"
  else
    echo "    \"name\": ${project_name:+\"$project_name\"}${project_name:-null},"
    echo "    \"file\": null,"
    echo "    \"hooks\": {}"
  fi

  echo "  }"
  echo "}"
}

# Add a hook
hooks_add() {
  local project_name="$1"
  local global_only="$2"
  local hook_type="$3"
  local matcher="$4"
  local command="$5"

  # Validate hook type
  case "$hook_type" in
    PreToolUse|PostToolUse|PreRequest|PostRequest)
      ;;
    *)
      log_error "Invalid hook type: $hook_type"
      log_info "Valid types: PreToolUse, PostToolUse, PreRequest, PostRequest"
      return 1
      ;;
  esac

  # Determine target file
  local target_file
  if [ "$global_only" = true ] || [ -z "$project_name" ]; then
    target_file="$AGENTS_HOME/settings/global/claude-code.json"
    log_info "Adding hook to global settings"
  else
    target_file="$AGENTS_HOME/settings/$project_name/claude-code.json"
    log_info "Adding hook to project: $project_name"
  fi

  # Ensure file exists
  if [ ! -f "$target_file" ]; then
    log_error "Settings file not found: $target_file"
    return 1
  fi

  # Build the new hook entry
  local new_hook
  new_hook=$(jq -n \
    --arg matcher "$matcher" \
    --arg command "$command" \
    '{
      "matcher": $matcher,
      "hooks": [
        {
          "type": "command",
          "command": $command
        }
      ]
    }')

  # Add to existing hooks
  local updated
  updated=$(jq \
    --arg type "$hook_type" \
    --argjson hook "$new_hook" \
    '.hooks[$type] = ((.hooks[$type] // []) + [$hook])' \
    "$target_file")

  # Write back
  echo "$updated" > "$target_file"

  log_success "Added $hook_type hook"
  echo -e "  Matcher: ${YELLOW}$matcher${NC}"
  echo -e "  Command: ${DIM}$command${NC}"
}

# Remove a hook
hooks_remove() {
  local project_name="$1"
  local global_only="$2"
  local hook_type="$3"
  local index="$4"

  # Validate hook type
  case "$hook_type" in
    PreToolUse|PostToolUse|PreRequest|PostRequest)
      ;;
    *)
      log_error "Invalid hook type: $hook_type"
      return 1
      ;;
  esac

  # Validate index is a number
  if ! [[ "$index" =~ ^[0-9]+$ ]]; then
    log_error "Index must be a number"
    return 1
  fi

  # Determine target file
  local target_file
  if [ "$global_only" = true ] || [ -z "$project_name" ]; then
    target_file="$AGENTS_HOME/settings/global/claude-code.json"
  else
    target_file="$AGENTS_HOME/settings/$project_name/claude-code.json"
  fi

  # Ensure file exists
  if [ ! -f "$target_file" ]; then
    log_error "Settings file not found: $target_file"
    return 1
  fi

  # Check if index exists
  local count
  count=$(jq -r ".hooks.$hook_type | length" "$target_file" 2>/dev/null || echo "0")

  if [ "$index" -ge "$count" ]; then
    log_error "Invalid index: $index (only $count hooks exist)"
    return 1
  fi

  # Remove the hook at index
  local updated
  updated=$(jq \
    --arg type "$hook_type" \
    --argjson idx "$index" \
    '.hooks[$type] = [.hooks[$type][] | select(. != .hooks[$type][$idx])] | .hooks[$type] |= del(.[$idx])' \
    "$target_file")

  # Simpler approach: rebuild array without the index
  updated=$(jq \
    --arg type "$hook_type" \
    --argjson idx "$index" \
    '.hooks[$type] = ([.hooks[$type] | to_entries[] | select(.key != $idx) | .value])' \
    "$target_file")

  # Write back
  echo "$updated" > "$target_file"

  log_success "Removed $hook_type hook at index $index"
}

# Open settings file in editor
hooks_edit() {
  local project_name="$1"
  local global_only="$2"

  local editor="${EDITOR:-vi}"

  # Determine target file
  local target_file
  if [ "$global_only" = true ] || [ -z "$project_name" ]; then
    target_file="$AGENTS_HOME/settings/global/claude-code.json"
  else
    target_file="$AGENTS_HOME/settings/$project_name/claude-code.json"
  fi

  if [ ! -f "$target_file" ]; then
    log_error "Settings file not found: $target_file"
    return 1
  fi

  log_info "Opening in $editor: $target_file"
  "$editor" "$target_file"
}

# Show example hooks
hooks_examples() {
  cat << 'EOF'

╔══════════════════════════════════════════════════════════════════════════════╗
║                           Claude Code Hook Examples                          ║
╚══════════════════════════════════════════════════════════════════════════════╝

┌──────────────────────────────────────────────────────────────────────────────┐
│ 1. COMMAND LOGGING                                                           │
│    Log all Bash commands to a file                                           │
└──────────────────────────────────────────────────────────────────────────────┘

  dot-agents hooks add PreToolUse \
    --matcher "Bash" \
    --command "echo \"[\$(date '+%Y-%m-%d %H:%M:%S')] \$TOOL_INPUT\" >> ~/.claude/command-log.txt"

┌──────────────────────────────────────────────────────────────────────────────┐
│ 2. DESKTOP NOTIFICATIONS (macOS)                                             │
│    Get notified when Claude completes a tool                                 │
└──────────────────────────────────────────────────────────────────────────────┘

  dot-agents hooks add PostToolUse \
    --matcher "*" \
    --command "osascript -e 'display notification \"Tool completed\" with title \"Claude\"'"

┌──────────────────────────────────────────────────────────────────────────────┐
│ 3. AUTO-FORMAT ON EDIT                                                       │
│    Run Prettier on files after Claude edits them                             │
└──────────────────────────────────────────────────────────────────────────────┘

  dot-agents hooks add PostToolUse \
    --matcher "Edit" \
    --command "npx prettier --write \"\$TOOL_INPUT\" 2>/dev/null || true"

┌──────────────────────────────────────────────────────────────────────────────┐
│ 4. TEST BEFORE COMMIT                                                        │
│    Run tests before git commit commands                                      │
└──────────────────────────────────────────────────────────────────────────────┘

  dot-agents hooks add PreToolUse \
    --matcher "Bash(git:commit:*)" \
    --command "npm test"

┌──────────────────────────────────────────────────────────────────────────────┐
│ 5. LINT CHECK                                                                │
│    Run ESLint after file edits                                               │
└──────────────────────────────────────────────────────────────────────────────┘

  dot-agents hooks add PostToolUse \
    --matcher "Edit" \
    --command "npx eslint \"\$TOOL_INPUT\" --fix 2>/dev/null || true"

┌──────────────────────────────────────────────────────────────────────────────┐
│ 6. SECURITY AUDIT                                                            │
│    Log any commands that modify sensitive files                              │
└──────────────────────────────────────────────────────────────────────────────┘

  dot-agents hooks add PreToolUse \
    --matcher "Edit" \
    --command "echo \"\$TOOL_INPUT\" | grep -qE '\\.env|secrets|credentials' && \
      echo \"[SECURITY] Edit to sensitive file: \$TOOL_INPUT\" >> ~/.claude/security.log || true"

────────────────────────────────────────────────────────────────────────────────

Matchers:
  "*"                   Match all tools
  "Bash"                Match Bash tool only
  "Edit"                Match Edit tool only
  "Bash(git:*)"         Match git commands
  "Bash(npm:*)"         Match npm commands
  "Bash(rm:-rf:*)"      Match dangerous rm commands

Environment variables available in hooks:
  $TOOL_INPUT           The tool's input/arguments
  $TOOL_OUTPUT          The tool's output (PostToolUse only)
  $SESSION_ID           Current Claude session ID

EOF
}

# Detect current project from working directory
detect_current_project() {
  local cwd
  cwd=$(pwd)

  # Check if we're in a registered project
  if [ -f "$AGENTS_HOME/config.json" ]; then
    local projects
    projects=$(jq -r '.projects | to_entries[] | "\(.key):\(.value.path)"' "$AGENTS_HOME/config.json" 2>/dev/null)

    while IFS=: read -r name path; do
      path=$(expand_path "$path")
      if [[ "$cwd" == "$path"* ]]; then
        echo "$name"
        return
      fi
    done <<< "$projects"
  fi

  # Not in a registered project
  echo ""
}
