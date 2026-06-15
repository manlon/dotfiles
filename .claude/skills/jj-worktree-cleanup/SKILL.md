---
name: jj-worktree-cleanup
description: >
  Clean up unused jj-workspace worktrees under .claude/worktrees/. Detects which
  worktrees have no live Claude Code session using them and removes them (jj
  workspace forget + rm -rf), preserving any with a .keep marker. Use when asked
  to clean up, prune, or remove stale/unused worktrees or workspaces.
user_invocable: true
---

# JJ Worktree Cleanup

These worktrees are jj **workspaces** (created by the WorktreeCreate hook as
`jj workspace add`), not git worktrees. A workspace is safe to remove when no
**live** Claude Code session is working inside it. There is no "uncommitted
changes" hazard: jj snapshots the working copy into `@` on any operation, so
running `jj status` first preserves the work as a commit that survives
`jj workspace forget` + `rm -rf` (it stays reachable by change id / op-log).

## Instructions

1. Run the scan script to classify every worktree:

   ```bash
   bash ~/.claude/skills/jj-worktree-cleanup/scan.sh
   ```

   Each line is `STATUS<TAB>name<TAB>path<TAB>detail`:
   - **IN_USE** — a live session's cwd is inside it. Never touch.
   - **KEEP** — a `.keep` marker is present. Preserve.
   - **REMOVE** — no live session, no marker. Safe to remove.
   - **ORPHAN** — a directory with no matching jj workspace. `rm -rf` only (no `jj workspace forget`).

2. If there are no REMOVE/ORPHAN lines, report that everything is in use or
   kept, and stop.

3. For each **REMOVE** entry, from the main checkout:

   ```bash
   jj -R "<path>" status >/dev/null   # force a working-copy snapshot first
   jj workspace forget "<name>"
   rm -rf "<path>"
   ```

   For each **ORPHAN** entry, just `rm -rf "<path>"`.

4. Report what was removed and what was left (with the reason: in use / .keep).

Removal is safe and reversible enough that you don't need to confirm each clean
REMOVE individually — just summarize at the end. Do call out anything surprising
(e.g. a worktree whose `@` is "has changes" rather than "empty") so the user
knows real work was snapshotted before deletion.
