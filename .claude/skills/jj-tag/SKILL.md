---
name: jj-tag
description: Set a bookmark on the current jj revision suitable for a GitHub PR branch name
disable-model-invocation: true
allowed-tools: Bash(jj *), Bash(date *)
---

# Tag Current Revision with a PR Branch Name

Create a bookmark on the current jj revision using a short, descriptive name suitable for a GitHub PR branch.

## Naming Convention

Format: `YYMMDD-short-dash-delimited-name`

Examples:
- `260214-deliv-card-footer`
- `260214-user-seed-is-client`
- `260213-workflow-progress-collapse`

## Steps

1. Run `date +%y%m%d` to get today's 6-digit date prefix
2. Run `jj diff --git` to see the current changes (ALWAYS use `--git` flag)
3. Run `jj log --limit 5` to see recent context and any existing bookmarks
4. Analyze the changes and craft a short dash-delimited suffix (2-4 words) that captures the essence of the work
   - Keep it concise but descriptive
   - Use lowercase, dash-delimited words
   - Abbreviate common terms (e.g., `deliv` for deliverables, `wf` for workflow)
5. Run `jj bookmark set YYMMDD-short-name` to set the bookmark on the current revision (defaults to `@`)
6. Confirm the bookmark was set by running `jj log --limit 1`
