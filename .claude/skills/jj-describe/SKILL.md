---
name: jj-describe
description: Describe the current jj revision with a well-crafted commit message
disable-model-invocation: true
allowed-tools: Bash(jj *)
---

# Describe Current Revision

Write a commit message for the current jj working copy and apply it with `jj describe`.

## Steps

1. Run `jj diff --git` to see the current changes (ALWAYS use `--git` flag)
2. Run `jj log --limit 5` to see recent commit message style
3. Analyze the changes and write a clear commit message:
   - First line: concise summary of what changed and why
   - If needed, add a blank line then a body explaining context
4. Apply with `jj describe -m "message"`
