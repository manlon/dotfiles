---
name: jj-review
description: Code review a PR branch using jj. Use when the user wants to review a branch, PR, or code changes.
argument-hint: <branch-name>
disable-model-invocation: true
---

# Code Review: Branch `$0`

You are helping the user do a code review of the branch `$0`.

## Steps

1. **Check out the branch** by running:
   ```
   jj new $0@origin
   ```

2. **View all changes** relative to main:
   ```
   jj diff --git -r main..@
   ```

3. **Review the changes** and share your analysis. Look for:
   - Correctness — bugs, logic errors, edge cases, off-by-one mistakes
   - Clarity — confusing names, unclear intent, missing context
   - Consistency — does it follow the conventions in CLAUDE.md?
   - Test coverage — are new/changed code paths tested?
   - Security — injection, auth gaps, data exposure
   - Performance — N+1 queries, unnecessary allocations, missing indexes

4. **Summarize your review:**
   - Start with a brief overview of what the branch does
   - Call out any concerns, grouped by severity (blocking vs. nit)
   - If everything looks good, say so — don't invent problems

Be direct and specific. Reference file paths and line numbers. If you need more context on a particular module, read the relevant files.
