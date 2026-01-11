---
name: "Self-Review"
description: "Review your own changes before committing or creating a pull request"
---

# Self-Review

Review your own changes before committing or creating a pull request.

## When to Use

- Before committing significant changes
- Before creating a pull request
- After implementing a feature or fix
- When you want to catch issues before code review

## Steps

1. **Review the diff**
   - Run `git diff` to see all changes
   - Check each file for unintended modifications
   - Look for debugging code or console.logs to remove

2. **Code quality check**
   - Are variable and function names clear?
   - Is the code readable and well-organized?
   - Are there any code smells or anti-patterns?
   - Is error handling appropriate?

3. **Logic verification**
   - Does the code do what it's supposed to?
   - Are edge cases handled?
   - Are there any potential bugs or race conditions?

4. **Test coverage**
   - Are there tests for new functionality?
   - Do existing tests still pass?
   - Are error cases tested?

5. **Documentation**
   - Are complex sections commented?
   - Is public API documented?
   - Are any README updates needed?

6. **Security check**
   - No hardcoded secrets or credentials?
   - Input validation present where needed?
   - No SQL injection or XSS vulnerabilities?

7. **Performance consideration**
   - Any obvious performance issues?
   - Unnecessary loops or API calls?
   - Large data structures handled efficiently?

## Checklist

- [ ] No debugging code left in
- [ ] All tests pass
- [ ] No linting errors
- [ ] Commit message is clear and descriptive
- [ ] Changes are focused (single responsibility)
- [ ] No unrelated changes included

## Notes

- Take your time - catching issues now saves review cycles
- If unsure about something, ask before committing
- It's okay to split large changes into multiple commits
