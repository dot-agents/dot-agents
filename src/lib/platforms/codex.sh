#!/bin/bash
# dot-agents/lib/platforms/codex.sh
# OpenAI Codex CLI detection, version, and linking

# Detect Codex CLI version
codex_detect() {
  if command -v codex >/dev/null 2>&1; then
    codex --version 2>/dev/null | head -1
  fi
}

# Check if Codex is installed
codex_is_installed() {
  command -v codex >/dev/null 2>&1
}

# Get Codex version string
codex_version() {
  codex_detect
}

# Create links for Codex (SYMLINKS - works fine)
codex_create_links() {
  local project="$1"
  local repo_path="$2"

  # Link AGENTS.md from global rules if it exists
  if [ -f "$AGENTS_HOME/rules/global/agents.md" ]; then
    ln -sf "$AGENTS_HOME/rules/global/agents.md" "$repo_path/AGENTS.md"
  elif [ -f "$AGENTS_HOME/rules/global/rules.md" ]; then
    # Fall back to global rules.md if no agents-specific file
    ln -sf "$AGENTS_HOME/rules/global/rules.md" "$repo_path/AGENTS.md"
  fi

  # Project-specific AGENTS.md
  if [ -f "$AGENTS_HOME/rules/$project/agents.md" ]; then
    # If project has its own agents.md, use it instead
    ln -sf "$AGENTS_HOME/rules/$project/agents.md" "$repo_path/AGENTS.md"
  fi

  # Create .codex directory for config
  mkdir -p "$repo_path/.codex"

  # Link TOML config if exists (Codex uses TOML, not JSON)
  if [ -f "$AGENTS_HOME/settings/$project/codex.toml" ]; then
    ln -sf "$AGENTS_HOME/settings/$project/codex.toml" "$repo_path/.codex/config.toml"
  elif [ -f "$AGENTS_HOME/settings/global/codex.toml" ]; then
    ln -sf "$AGENTS_HOME/settings/global/codex.toml" "$repo_path/.codex/config.toml"
  fi
}

# Check for deprecated formats (Codex has been stable - no deprecated formats)
codex_has_deprecated_format() {
  local repo_path="$1"
  return 1  # No deprecated formats for Codex
}

# Get deprecated format details
codex_deprecated_details() {
  local repo_path="$1"
  # Codex has no deprecated formats
  echo ""
}

# Create skills symlinks for Codex CLI (directory-based)
# Symlinks global and project skills to .codex/skills/ so they work as slash commands
# Project skills override global skills with the same name (with warning)
codex_create_skills_links() {
  local project="$1"
  local repo_path="$2"

  local skills_target="$repo_path/.codex/skills"
  local global_skills="$AGENTS_HOME/skills/global"
  local project_skills="$AGENTS_HOME/skills/$project"

  # Create skills directory
  mkdir -p "$skills_target"

  # Collect project skill names (for conflict detection)
  local project_skill_names=""
  if [ -d "$project_skills" ]; then
    for skill_dir in "$project_skills"/*/; do
      [ -d "$skill_dir" ] || continue
      [ -f "$skill_dir/SKILL.md" ] || continue
      local name
      name=$(basename "$skill_dir")
      project_skill_names="$project_skill_names $name "
    done
  fi

  # Symlink global skills (no prefix, skip if shadowed by project skill)
  if [ -d "$global_skills" ]; then
    for skill_dir in "$global_skills"/*/; do
      [ -d "$skill_dir" ] || continue
      [ -f "$skill_dir/SKILL.md" ] || continue
      local name
      name=$(basename "$skill_dir")
      local target="$skills_target/$name"

      # Check if project has a skill with the same name
      if [[ "$project_skill_names" == *" $name "* ]]; then
        # Project skill shadows global - warn and skip
        echo -e "  ${YELLOW}⚠${NC}  Skill '$name' shadows global skill (project overrides global)" >&2
        continue
      fi

      # Only create if doesn't exist
      [ -e "$target" ] || [ -L "$target" ] || ln -sf "$skill_dir" "$target"
    done
  fi

  # Symlink project skills (no prefix)
  if [ -d "$project_skills" ]; then
    for skill_dir in "$project_skills"/*/; do
      [ -d "$skill_dir" ] || continue
      [ -f "$skill_dir/SKILL.md" ] || continue
      local name
      name=$(basename "$skill_dir")
      local target="$skills_target/$name"
      # Only create if doesn't exist
      [ -e "$target" ] || [ -L "$target" ] || ln -sf "$skill_dir" "$target"
    done
  fi
}
