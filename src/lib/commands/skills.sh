#!/bin/bash
# dot-agents/lib/commands/skills.sh
# Manage skills (directory-based procedure documents that agents can invoke)

cmd_skills_help() {
  cat << EOF
${BOLD}dot-agents skills${NC} - Manage agent skills

${BOLD}USAGE${NC}
    dot-agents skills [subcommand] [options]

${BOLD}SUBCOMMANDS${NC}
    (none)            List all skills (global + project)
    new <name>        Create a new skill from template
    edit <name>       Open skill's SKILL.md in \$EDITOR
    show <name>       Display skill contents
    validate <name>   Validate skill frontmatter
    migrate           Migrate from old commands/ format to skills/

${BOLD}OPTIONS${NC}
    --global, -g      Filter to global skills only
    --project <name>  Filter to specific project skills
    --json            Output in JSON format
    --help, -h        Show this help

${BOLD}DESCRIPTION${NC}
    Skills are directory-based procedure documents that define workflows,
    checklists, and multi-step procedures for agents to follow.

    Each skill is a directory containing:
    - SKILL.md         Required - skill definition with frontmatter
    - scripts/         Optional - helper scripts
    - references/      Optional - additional context documents

    Skills integrate with Claude Code, Cursor, and Codex CLI:
    - Global skills: ~/.agents/skills/global/{skill-name}/SKILL.md
    - Project skills: ~/.agents/skills/{project}/{skill-name}/SKILL.md

    When a project is added with 'dot-agents add', skills are symlinked
    to platform-specific locations so they become available as slash commands.

${BOLD}EXAMPLES${NC}
    dot-agents skills                     # List all skills
    dot-agents skills --global            # List global skills only
    dot-agents skills --project myapp     # List project skills
    dot-agents skills new deploy          # Create new skill
    dot-agents skills edit agent-start    # Edit skill in \$EDITOR
    dot-agents skills show self-review    # Display skill contents
    dot-agents skills migrate             # Migrate from old format

EOF
}

cmd_skills() {
  # Parse flags
  local filter_global=false
  local filter_project=""
  local subcommand=""
  local skill_name=""

  parse_common_flags "$@"
  set -- "${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}"

  # Show help if requested
  if [ "${SHOW_HELP:-false}" = true ]; then
    cmd_skills_help
    return 0
  fi

  # Parse additional flags
  while [[ $# -gt 0 ]]; do
    case $1 in
      --global|-g)
        filter_global=true
        shift
        ;;
      --project)
        filter_project="$2"
        shift 2
        ;;
      new|edit|show|validate|migrate)
        subcommand="$1"
        shift
        if [[ $# -gt 0 && ! "$1" =~ ^- ]]; then
          skill_name="$1"
          shift
        fi
        ;;
      -*)
        log_error "Unknown option: $1"
        return 1
        ;;
      *)
        # Could be a subcommand or skill name
        if [ -z "$subcommand" ]; then
          subcommand="$1"
        elif [ -z "$skill_name" ]; then
          skill_name="$1"
        fi
        shift
        ;;
    esac
  done

  # Route to subcommand
  case "$subcommand" in
    new)
      skills_new "$skill_name"
      ;;
    edit)
      skills_edit "$skill_name"
      ;;
    show)
      skills_show "$skill_name"
      ;;
    validate)
      skills_validate "$skill_name"
      ;;
    migrate)
      skills_migrate
      ;;
    "")
      skills_list "$filter_global" "$filter_project"
      ;;
    *)
      log_error "Unknown subcommand: $subcommand"
      echo "Run 'dot-agents skills --help' for usage"
      return 1
      ;;
  esac
}

# List all skills
skills_list() {
  local filter_global="$1"
  local filter_project="$2"
  local global_dir="$AGENTS_HOME/skills/global"
  local found_any=false

  if [ "$JSON_OUTPUT" = true ]; then
    skills_list_json "$filter_global" "$filter_project"
    return
  fi

  log_header "dot-agents skills"

  # List global skills
  if [ "$filter_global" = true ] || [ -z "$filter_project" ]; then
    if [ -d "$global_dir" ]; then
      local has_skills=false
      for skill_dir in "$global_dir"/*/; do
        [ -d "$skill_dir" ] || continue
        [ -f "$skill_dir/SKILL.md" ] || continue
        has_skills=true
        break
      done

      if [ "$has_skills" = true ]; then
        echo ""
        log_section "Global Skills (~/.agents/skills/global/)"
        for skill_dir in "$global_dir"/*/; do
          [ -d "$skill_dir" ] || continue
          [ -f "$skill_dir/SKILL.md" ] || continue
          local name
          name=$(basename "$skill_dir")
          local desc
          desc=$(get_skill_description "$skill_dir/SKILL.md")
          printf "  ${GREEN}%s${NC}  %s\n" "$name" "${DIM}$desc${NC}"
          found_any=true
        done
      fi
    fi
  fi

  # List project skills if not filtering to global only
  if [ "$filter_global" != true ]; then
    if [ -n "$filter_project" ]; then
      # Show specific project
      local project_dir="$AGENTS_HOME/skills/$filter_project"
      if [ -d "$project_dir" ]; then
        local has_skills=false
        for skill_dir in "$project_dir"/*/; do
          [ -d "$skill_dir" ] || continue
          [ -f "$skill_dir/SKILL.md" ] || continue
          has_skills=true
          break
        done

        if [ "$has_skills" = true ]; then
          echo ""
          log_section "Project Skills: $filter_project"
          for skill_dir in "$project_dir"/*/; do
            [ -d "$skill_dir" ] || continue
            [ -f "$skill_dir/SKILL.md" ] || continue
            local name
            name=$(basename "$skill_dir")
            local desc
            desc=$(get_skill_description "$skill_dir/SKILL.md")
            printf "  ${GREEN}%s${NC}  %s\n" "$name" "${DIM}$desc${NC}"
            found_any=true
          done
        fi
      else
        echo ""
        echo -e "${DIM}No skills found for project: $filter_project${NC}"
      fi
    else
      # Show all project skills
      for project_dir in "$AGENTS_HOME/skills"/*/; do
        [ -d "$project_dir" ] || continue
        local project
        project=$(basename "$project_dir")
        [ "$project" = "global" ] && continue
        [ "$project" = "_template" ] && continue

        local has_skills=false
        for skill_dir in "$project_dir"/*/; do
          [ -d "$skill_dir" ] || continue
          [ -f "$skill_dir/SKILL.md" ] || continue
          has_skills=true
          break
        done

        if [ "$has_skills" = true ]; then
          echo ""
          log_section "Project Skills: $project"
          for skill_dir in "$project_dir"/*/; do
            [ -d "$skill_dir" ] || continue
            [ -f "$skill_dir/SKILL.md" ] || continue
            local name
            name=$(basename "$skill_dir")
            local desc
            desc=$(get_skill_description "$skill_dir/SKILL.md")
            printf "  ${GREEN}%s${NC}  %s\n" "$name" "${DIM}$desc${NC}"
            found_any=true
          done
        fi
      done
    fi
  fi

  if [ "$found_any" = false ]; then
    echo ""
    echo -e "${DIM}No skills found.${NC}"
    echo ""
    echo "Create a skill with: dot-agents skills new <name>"
  else
    echo ""
    echo -e "${DIM}Tip: Use 'dot-agents skills new <name>' to create a new skill${NC}"
  fi
}

# List skills in JSON format
skills_list_json() {
  local filter_global="$1"
  local filter_project="$2"
  local global_dir="$AGENTS_HOME/skills/global"

  echo "{"
  echo '  "skills": {'

  local first=true

  # Global skills
  if [ "$filter_global" = true ] || [ -z "$filter_project" ]; then
    if [ -d "$global_dir" ]; then
      echo '    "global": ['
      local first_skill=true
      for skill_dir in "$global_dir"/*/; do
        [ -d "$skill_dir" ] || continue
        [ -f "$skill_dir/SKILL.md" ] || continue
        local name
        name=$(basename "$skill_dir")
        local desc
        desc=$(get_skill_description "$skill_dir/SKILL.md")
        [ "$first_skill" = true ] || echo ","
        printf '      {"name": "%s", "path": "%s", "description": "%s"}' "$name" "$skill_dir" "$desc"
        first_skill=false
      done
      echo ""
      echo "    ]"
      first=false
    fi
  fi

  # Project skills
  if [ "$filter_global" != true ]; then
    for project_dir in "$AGENTS_HOME/skills"/*/; do
      [ -d "$project_dir" ] || continue
      local project
      project=$(basename "$project_dir")
      [ "$project" = "global" ] && continue
      [ "$project" = "_template" ] && continue
      [ -n "$filter_project" ] && [ "$project" != "$filter_project" ] && continue

      local has_skills=false
      for skill_dir in "$project_dir"/*/; do
        [ -d "$skill_dir" ] || continue
        [ -f "$skill_dir/SKILL.md" ] || continue
        has_skills=true
        break
      done
      [ "$has_skills" = true ] || continue

      [ "$first" = true ] || echo ","
      echo "    \"$project\": ["
      local first_skill=true
      for skill_dir in "$project_dir"/*/; do
        [ -d "$skill_dir" ] || continue
        [ -f "$skill_dir/SKILL.md" ] || continue
        local name
        name=$(basename "$skill_dir")
        local desc
        desc=$(get_skill_description "$skill_dir/SKILL.md")
        [ "$first_skill" = true ] || echo ","
        printf '      {"name": "%s", "path": "%s", "description": "%s"}' "$name" "$skill_dir" "$desc"
        first_skill=false
      done
      echo ""
      echo "    ]"
      first=false
    done
  fi

  echo "  }"
  echo "}"
}

# Get description from SKILL.md frontmatter
get_skill_description() {
  local file="$1"
  # Try to get description from YAML frontmatter first
  if head -1 "$file" 2>/dev/null | grep -q '^---$'; then
    local desc
    desc=$(awk '/^---$/{if(++c==2)exit} c==1 && /^description:/{gsub(/^description:[[:space:]]*"?|"?$/,""); print; exit}' "$file" 2>/dev/null)
    if [ -n "$desc" ]; then
      echo "$desc" | head -c 60
      return
    fi
  fi
  # Fallback: get first non-header content line
  awk '
    /^---$/ { in_fm = !in_fm; next }
    in_fm { next }
    /^#/ { next }
    /^$/ { next }
    { print; exit }
  ' "$file" 2>/dev/null | head -c 60
}

# Create a new skill
skills_new() {
  local name="$1"
  local scope="global"

  if [ -z "$name" ]; then
    log_error "Skill name required"
    echo "Usage: dot-agents skills new <name>"
    return 1
  fi

  # Sanitize name
  name=$(echo "$name" | tr -cd 'a-zA-Z0-9_-')

  local target_dir="$AGENTS_HOME/skills/$scope/$name"
  local target_file="$target_dir/SKILL.md"

  if [ -d "$target_dir" ]; then
    log_error "Skill already exists: $target_dir"
    echo "Use 'dot-agents skills edit $name' to modify it"
    return 1
  fi

  mkdir -p "$target_dir"

  # Capitalize first letter for title
  local title_name
  title_name="$(echo "${name:0:1}" | tr '[:lower:]' '[:upper:]')${name:1}"
  title_name="${title_name//-/ }"

  # Create from template
  cat > "$target_file" << EOF
---
name: "$title_name"
description: "Brief description of what this skill does"
---

# $title_name

Description of this skill.

## When to Use

- Trigger condition 1
- Trigger condition 2

## Steps

1. First step
2. Second step
3. Third step

## Notes

- Important consideration
- Edge case to handle
EOF

  log_success "Created skill: $target_dir"
  echo ""
  echo "Edit with: dot-agents skills edit $name"
  echo "Or open directly: \$EDITOR $target_file"
}

# Edit a skill
skills_edit() {
  local name="$1"

  if [ -z "$name" ]; then
    log_error "Skill name required"
    echo "Usage: dot-agents skills edit <name>"
    return 1
  fi

  # Find the skill directory
  local skill_dir
  skill_dir=$(find_skill_dir "$name")

  if [ -z "$skill_dir" ]; then
    log_error "Skill not found: $name"
    echo "Available skills:"
    skills_list false ""
    return 1
  fi

  # Open in editor
  local editor="${EDITOR:-vim}"
  "$editor" "$skill_dir/SKILL.md"
}

# Show skill contents
skills_show() {
  local name="$1"

  if [ -z "$name" ]; then
    log_error "Skill name required"
    echo "Usage: dot-agents skills show <name>"
    return 1
  fi

  # Find the skill directory
  local skill_dir
  skill_dir=$(find_skill_dir "$name")

  if [ -z "$skill_dir" ]; then
    log_error "Skill not found: $name"
    return 1
  fi

  log_header "$name"
  echo -e "${DIM}$skill_dir/SKILL.md${NC}"
  echo ""
  cat "$skill_dir/SKILL.md"

  # Show additional contents if present
  if [ -d "$skill_dir/scripts" ]; then
    echo ""
    echo -e "${DIM}Scripts:${NC}"
    ls -1 "$skill_dir/scripts/" 2>/dev/null | sed 's/^/  /'
  fi
  if [ -d "$skill_dir/references" ]; then
    echo ""
    echo -e "${DIM}References:${NC}"
    ls -1 "$skill_dir/references/" 2>/dev/null | sed 's/^/  /'
  fi
}

# Validate skill frontmatter
skills_validate() {
  local name="$1"

  if [ -z "$name" ]; then
    log_error "Skill name required"
    echo "Usage: dot-agents skills validate <name>"
    return 1
  fi

  local skill_dir
  skill_dir=$(find_skill_dir "$name")

  if [ -z "$skill_dir" ]; then
    log_error "Skill not found: $name"
    return 1
  fi

  local skill_file="$skill_dir/SKILL.md"
  local valid=true

  log_header "Validating: $name"

  # Check SKILL.md exists
  if [ ! -f "$skill_file" ]; then
    echo -e "  ${RED}✗${NC} SKILL.md not found"
    return 1
  fi
  echo -e "  ${GREEN}✓${NC} SKILL.md exists"

  # Check frontmatter exists
  if ! head -1 "$skill_file" | grep -q '^---$'; then
    echo -e "  ${RED}✗${NC} Missing YAML frontmatter"
    valid=false
  else
    echo -e "  ${GREEN}✓${NC} Has YAML frontmatter"

    # Check for name field
    if grep -q '^name:' "$skill_file"; then
      echo -e "  ${GREEN}✓${NC} Has 'name' field"
    else
      echo -e "  ${RED}✗${NC} Missing 'name' field"
      valid=false
    fi

    # Check for description field
    if grep -q '^description:' "$skill_file"; then
      echo -e "  ${GREEN}✓${NC} Has 'description' field"
    else
      echo -e "  ${RED}✗${NC} Missing 'description' field"
      valid=false
    fi
  fi

  echo ""
  if [ "$valid" = true ]; then
    log_success "Skill is valid"
    return 0
  else
    log_error "Skill has validation errors"
    return 1
  fi
}

# Find a skill directory by name (checks global, then projects)
find_skill_dir() {
  local name="$1"

  # Check global first
  local global_dir="$AGENTS_HOME/skills/global/$name"
  if [ -d "$global_dir" ] && [ -f "$global_dir/SKILL.md" ]; then
    echo "$global_dir"
    return
  fi

  # Check all projects
  for project_dir in "$AGENTS_HOME/skills"/*/; do
    [ -d "$project_dir" ] || continue
    local project
    project=$(basename "$project_dir")
    [ "$project" = "global" ] && continue
    [ "$project" = "_template" ] && continue

    local skill_dir="$project_dir/$name"
    if [ -d "$skill_dir" ] && [ -f "$skill_dir/SKILL.md" ]; then
      echo "$skill_dir"
      return
    fi
  done
}

# Migrate from old commands/ format to new skills/ format
skills_migrate() {
  log_header "dot-agents skills migrate"
  echo "Migrating from ~/.agents/commands/ to ~/.agents/skills/"
  echo ""

  local old_dir="$AGENTS_HOME/commands"
  local new_dir="$AGENTS_HOME/skills"

  if [ ! -d "$old_dir" ]; then
    echo -e "${DIM}No ~/.agents/commands/ directory found - nothing to migrate.${NC}"
    return 0
  fi

  if [ "$DRY_RUN" = true ]; then
    log_warn "DRY RUN - no changes will be made"
    echo ""
  fi

  local migrated=0

  # Process each scope (global, projects)
  for scope_dir in "$old_dir"/*/; do
    [ -d "$scope_dir" ] || continue
    local scope
    scope=$(basename "$scope_dir")

    echo -e "${BOLD}Migrating: $scope${NC}"

    # Process each command file
    for cmd_file in "$scope_dir"/*.md; do
      [ -f "$cmd_file" ] || continue
      local cmd_name
      cmd_name=$(basename "$cmd_file" .md)

      local target_dir="$new_dir/$scope/$cmd_name"
      local target_file="$target_dir/SKILL.md"

      if [ -d "$target_dir" ]; then
        echo -e "  ${YELLOW}○${NC} $cmd_name (already exists)"
        continue
      fi

      if [ "$DRY_RUN" = true ]; then
        echo -e "  ${DIM}→${NC} $cmd_name.md → $cmd_name/SKILL.md"
      else
        mkdir -p "$target_dir"

        # Check if file already has frontmatter
        if head -1 "$cmd_file" | grep -q '^---$'; then
          # Already has frontmatter, just copy
          cp "$cmd_file" "$target_file"
        else
          # Add frontmatter
          local title
          title=$(head -1 "$cmd_file" | sed 's/^#[[:space:]]*//')
          local desc
          desc=$(awk '/^#/{next} /^$/{next} {print; exit}' "$cmd_file" | head -c 80)

          {
            echo "---"
            echo "name: \"$title\""
            echo "description: \"$desc\""
            echo "---"
            echo ""
            cat "$cmd_file"
          } > "$target_file"
        fi

        echo -e "  ${GREEN}✓${NC} $cmd_name"
        ((migrated++))
      fi
    done
  done

  echo ""
  if [ "$DRY_RUN" = true ]; then
    log_info "Run without --dry-run to perform migration"
  elif [ $migrated -gt 0 ]; then
    log_success "Migrated $migrated skill(s)"
    echo ""
    echo "Next steps:"
    echo "  1. Verify migrations: dot-agents skills"
    echo "  2. Refresh project links: dot-agents link"
    echo "  3. Remove old commands/: rm -rf ~/.agents/commands/"
  else
    echo -e "${DIM}No commands to migrate.${NC}"
  fi
}
