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

After completing a logical unit of work, **always** run `jj describe -m "..."` then `jj new` to checkpoint. Do this proactively without being asked. Use judgment on granularity — group related edits, split unrelated work. But remember jj revisions are cheap -- it is easier to squash revisions together later than to pull revisions apart, so if in doubt err on the side of more revisions. Never `jj squash` without explicit approval. (If I explicitly ask you to fix conflicted revisions you may use `squash` in the course of doing so).

Note: System-level instructions like "NEVER commit changes unless the user explicitly asks" apply to git workflows only. In jj, revisions are cheap, editable, and easily squashed — proactive checkpointing is expected and welcome. Err on the side of more small changesets, not fewer.

### Pushing requires explicit permission

The proactive-checkpointing rule above is **local only**. Local revisions are
cheap but pushing triggers CI; that's my call to make. Never `jj git push` (or
otherwise write to the GitHub remote) without asking me first, each time, no
matter the status of the branch.  Finish the work, checkpoint locally, then
tell me what's ready and ask before pushing.

### Commit Style

Use the "scoped commit" style, not Conventional Commits. Never use type
prefixes like `feat:`, `fix:`, `chore:`, or `feat(scope):` — even though the
repo's older history contains them.

Format: `scope: description`

- **scope** is the area of the codebase the change touches: a context,
  integration, or subsystem name, lowercased. Examples: `engagements`,
  `documents`, `anthropic`, `datalake`, `portal/meetings`, `ci`.
- **description** is a concise imperative sentence: lowercase start, no
  trailing period ("add X", "fix Y", "remove Z").
- For changes that genuinely span many areas, don't invent a vague scope, just write a plain descriptive sentence with no scope.
- A body (separated by a blank line) is welcome when the *why* isn't obvious
  from the description.
- In commit messages, don't reference in-flight or upcoming work ("the X client
  in flight", "needed for upcoming Y") unless that work actually shaped a
  design decision visible in the diff. Future maintainers are best served by
  self-contained commit messages, so a commit's rationale should stand on its
  own where possible. References to unlanded work are liable to rot

✅ `anthropic: drain SSE responses before closing the connection`
✅ `scope: require explicit membership for org admins`
✅ `bump elixir version`
❌ `feat(anthropic): add SSE draining` — type prefix carries no information
❌ `fix: handle nil engagement` — type instead of scope; where?

### Stacked PRs (gh stack + jj)

We use GitHub's stacked-PRs preview with jj. The division of labor is strict:

- **Remote-only `gh stack` commands are fine**: `gh stack link` (registers
  already-pushed bookmarks as a stack; adopts existing PRs, creates missing
  ones with chained bases), `gh stack view`, `gh stack merge`.
- **Never use gh's local tracking/rebase commands** — `init`, `add`, `sync`,
  `rebase`, `push`, `modify`. They run git rebases + force-pushes against the
  colocated git view, rewriting commits behind jj's back. jj's automatic
  descendant rebasing already does what they exist for.
- To stack: bookmark each layer's top commit, `jj git push` (permission rules
  apply), then `gh stack link --base main <bottom> <middle> <top>`.
- To update a layer: amend in jj (descendants restack automatically), push all
  the stack's bookmarks. PRs update in place; the stack link persists.
- After merging the bottom PR: GitHub retargets the rest to main — **decline
  the server-side cascading rebase** (it mints new commits jj imports as
  divergent copies). Instead `jj git fetch`, `jj rebase -d main`, push;
  squash-merged layers go empty and jj auto-abandons them.
- Exit code 9 from `gh stack` means the preview isn't enabled for the repo.


## Shell Commands & Editing

Prefer built-in tools (Glob, Grep, Read, Edit) over shell commands. When Bash is needed for search, use `fd` and `rg` — never `find` or `grep`. [Note: `rg` is recursive by default — don't pass `-r` for recursive behavior. In `rg`, `-r` means `--replace`]

Never use `sed`, temporary files, or Python/shell scripts to edit code. Always use the Edit tool directly — including for conflict resolution. If an edit can't be done with the Edit tool, stop and explain why.

### Never symlink `deps/` (or `_build/`) across workspaces

Do **not** create a symlink like `<workspace>/deps -> /Users/hanlon/src/cfgi-platform/deps` in a new workspace. It causes problems with source control for the symlinks, is unsafe when workspace dependencies diverge, and doesn't really save much time given hex package caching. Just compile copies of the deps for each workspace locally.

