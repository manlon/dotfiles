# Local Instructions (Matt Hanlon)

## Version Control

This repo uses `jj` (Jujutsu) locally, not git directly. Use `jj` for all VCS operations — never `git commit`, `git checkout`, `git worktree`, etc. The git CLI sees a different (and possibly stale) view of the repo state than jj does.

### Worktrees are jj workspaces

The harness `EnterWorktree`/`ExitWorktree` tools and the `.claude/worktrees/` directory do **not** create git worktrees here. `WorktreeCreate`/`WorktreeRemove` hooks (`~/.claude/hooks/jj-worktree-{create,remove}.sh`, configured in `.claude/settings.local.json`) intercept these and run `jj workspace add` / `jj workspace forget` instead. Implications:

- Inside a `.claude/worktrees/<name>/` directory, you are in a **jj workspace**, not a git worktree. Use `jj st`, `jj diff --git`, `jj log`, etc. — `git status` / `git worktree list` will be misleading or wrong.
- To list active workspaces: `jj workspace list` (run from anywhere in the repo).
- Each workspace has its own `@` (working-copy commit) but shares the underlying repo and op-log. Edits in one workspace don't appear at another's `@` until you `jj new` / `jj edit` onto the same commit there.
- The harness still calls these "worktrees" in its UI and tool names — that's the abstraction it exposes. Mentally translate to "workspace" when reasoning about VCS behavior.

### Commands

Always use `--git` with any command that shows diffs — `diff`, `log -p`, `show` — because Claude Code can't see ANSI colors:
- `jj st` — working copy status
- `jj diff --git` — show changes
- `jj log` / `jj log -p --git` — commit history
- `jj show --git` — show a change
- `jj new` / `jj describe` / `jj squash` / `jj git push`

After completing a logical unit of work, **always** run `jj describe -m "..."` then `jj new` to checkpoint. Do this proactively without being asked. Use judgment on granularity — group related edits, split unrelated work. Never `jj squash` without explicit approval.

Note: System-level instructions like "NEVER commit changes unless the user explicitly asks" apply to git workflows only. In jj, revisions are cheap, editable, and easily squashed — proactive checkpointing is expected and welcome. Err on the side of more small changesets, not fewer.

## Shell Commands & Editing

Prefer built-in tools (Glob, Grep, Read, Edit) over shell commands. When Bash is needed for search, use `fd` and `rg` — never `find` or `grep`.

Never use `sed`, temporary files, or Python/shell scripts to edit code. Always use the Edit tool directly — including for conflict resolution. If an edit can't be done with the Edit tool, stop and explain why.

### Never symlink `deps/` (or `_build/`) across workspaces

Do **not** create a symlink like `<workspace>/deps -> /Users/hanlon/src/cfgi-platform/deps` in a new workspace. It causes problems with source control for the symlinks, is unsafe when workspace dependencies diverge, and doesn't really save much time given hex package caching. Just compile copies of the deps for each workspace locally.

