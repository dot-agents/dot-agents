---
name: "Agent Handoff"
description: "Prepare for the next agent or session by documenting work and leaving codebase in good state"
---

# Agent Handoff

Prepare for the next agent or session by documenting your work and leaving the codebase in a good state.

## When to Use

- At the end of a work session
- Before switching to a different task
- When handing off to another developer or agent
- When context window is getting full

## Steps

1. **Commit completed work**
   - Stage and commit any finished changes
   - Write clear, descriptive commit messages
   - Don't leave partial work uncommitted unless necessary

2. **Document work in progress**
   - Add TODO comments for incomplete work
   - Update task lists or issue trackers
   - Note any decisions made and why

3. **Summarize the session**
   - What was accomplished?
   - What remains to be done?
   - Any blockers or issues encountered?

4. **Clean up**
   - Remove debugging code or console.logs
   - Delete temporary files
   - Ensure tests pass (or document why they don't)

5. **Leave notes for next session**
   - What should the next agent focus on?
   - Any context that would be helpful?
   - Links to relevant documentation or issues

## Notes

- Leave the codebase in a working state when possible
- Don't leave uncommitted debugging code
- Be explicit about what's done vs what's in progress
- The next agent has no context - write notes accordingly
