---
name: jj-review
description: Code review a PR branch using jj. Use when the user wants to review a branch, PR, or code changes.
argument-hint: <branch-name>
disable-model-invocation: true
---

# Code Review: Branch `$0`

You are helping the user do a code review of the branch `$0`.

## Steps

1. **Fetch the latest from the remote:**
   ```
   jj git fetch
   ```

2. **Check out the branch.** Use the local bookmark `$0` if it exists, otherwise fall back to the remote-tracking bookmark `$0@origin`:
   ```
   jj bookmark list $0
   ```
   If that lists a local bookmark, run `jj new $0`. If it only shows `$0@origin` (or nothing), run `jj new $0@origin`.

3. **View all changes** relative to main:
   ```
   jj diff --git -r main..@
   ```

4. **Review the changes** and share your analysis. Look for:
   - Correctness — bugs, logic errors, edge cases, off-by-one mistakes
   - Clarity — confusing names, unclear intent, missing context
   - Consistency — does it follow the conventions in CLAUDE.md?
   - Test coverage — are new/changed code paths tested?
   - Security — injection, auth gaps, data exposure
   - Performance — N+1 queries, unnecessary allocations, missing indexes

5. **Summarize your review:**
   - Start with a brief overview of what the branch does
   - Call out any concerns, grouped by severity (blocking vs. nit)
   - If everything looks good, say so — don't invent problems

Be direct and specific. Reference file paths and line numbers. If you need more context on a particular module, read the relevant files.
