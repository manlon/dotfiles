---
name: jj-context
description: >
  Infer context from local jj changes on top of main. Runs jj diff to summarize
  work done in the current branch, giving a fresh Claude Code session the context
  it needs to continue working.
user_invocable: true
---

# JJ Context Skill

## Instructions

1. Run the following command to get the full diff of local changes on top of main:

```bash
jj diff --git -r "main..@"
```

2. Analyze the diff output and produce a concise summary covering:
   - **What changed**: Which files were added, modified, or deleted
   - **What the work is about**: The feature, fix, or refactor being done — infer intent from the code changes
   - **Current state**: What appears complete vs. in-progress or incomplete

3. Display the summary to the user so we can proceed working on top of these changes.

Keep the summary short and actionable — focus on what matters for continuing the work.
