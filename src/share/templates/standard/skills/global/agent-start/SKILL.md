---
name: "Agent Start"
description: "Begin each work session by understanding the current state and context"
---

# Agent Start

Begin each work session by understanding the current state and context.

## When to Use

- At the start of a new conversation or coding session
- When resuming work after a break
- When switching to a different task

## Steps

1. **Check for existing context**
   - Read any TODO comments or task lists in the codebase
   - Check for CLAUDE.md or similar project documentation
   - Review any pinned messages or session notes

2. **Understand the current state**
   - Run `git status` to see uncommitted changes
   - Review recent commits with `git log --oneline -5`
   - Check for any failing tests or build issues

3. **Identify the current task**
   - Ask the user what they want to work on if not clear
   - Review any linked issues or tickets
   - Check the project backlog if available

4. **Plan before coding**
   - Break down complex tasks into smaller steps
   - Identify files that will need changes
   - Consider edge cases and potential issues

## Notes

- Don't start coding until you understand the goal
- Ask clarifying questions if requirements are unclear
- If picking up someone else's work, read their notes first
- Check for any blockers or dependencies before diving in
