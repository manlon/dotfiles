# Global Instructions (Matt Hanlon)

## Writing Style

Please remove all mannered prose.

## Version Control

Most of my repos are jj (Jujutsu) colocated with git. **Check for a `.jj/` directory at the repo root**: if it's there, use `jj` for all VCS operations — never `git commit`, `git checkout`, `git worktree`, etc. The git CLI sees a different (and possibly stale) view of the repo state than jj does. If you encounter a repo using plain git, warn me about it: I may want to continue using plain git for that repo or I may ask you to `jj git init` so we can proceed using `jj`.


### Worktrees are jj workspaces

In a jj repo, the harness `EnterWorktree`/`ExitWorktree` tools do **not** create git worktrees. `WorktreeCreate`/`WorktreeRemove` hooks (`~/.claude/hooks/jj-worktree-{create,remove}.sh`, registered globally in `~/.claude/settings.json`) intercept these and run `jj workspace add` / `jj workspace forget` instead, placing the workspace at `~/src/_worktrees/<repo>/<name>/` — outside the repo tree, so git doesn't discover the parent checkout and trip the harness's isolation check. Outside a jj repo the hooks exit silently and you get an ordinary git worktree under `.claude/worktrees/`. Implications:

- Inside a `~/src/_worktrees/<repo>/<name>/` directory, you are in a **jj workspace**, not a git worktree. Use `jj st`, `jj diff --git`, `jj log`, etc. — `git status` / `git worktree list` will be misleading or wrong.
- To list active workspaces: `jj workspace list` (run from anywhere in the repo).
- Each workspace has its own `@` (working-copy commit) but shares the underlying repo and op-log. Edits in one workspace don't appear at another's `@` until you `jj new` / `jj edit` onto the same commit there.
- The harness still calls these "worktrees" in its UI and tool names — that's the abstraction it exposes. Mentally translate to "workspace" when reasoning about VCS behavior.
- While a session is isolated in a workspace, the harness refuses `jj git …` commands (including `jj git push`) and any `cd` into the main checkout that runs git; this can't be turned off. Don't try to rephrase around it. Once I've approved a push, call `ExitWorktree` with `action: "keep"`, then run `jj git push -b <bookmark>` and any `gh` commands from the default workspace (the main checkout). Bookmarks are shared across workspaces, so this pushes the same commits. If more edits are needed afterwards, re-enter with `EnterWorktree` (`path:` the workspace) before editing.

### Commands

Always use `--git` with any command that shows diffs — `diff`, `log -p`, `show` — because Claude Code can't see ANSI colors:
- `jj st` — working copy status
- `jj diff --git` — show changes
- `jj log` / `jj log -p --git` — commit history
- `jj show --git` — show a change
- `jj new` / `jj describe` / `jj squash` / `jj git push`

After completing a logical unit of work, **always** run `jj describe -m "..."` then `jj new` to checkpoint. Do this proactively without being asked. Use judgment on granularity — group related edits, split unrelated work. But remember jj revisions are cheap — it is easier to squash revisions together later than to pull revisions apart, so if in doubt err on the side of more revisions. Never `jj squash` without explicit approval. (If I explicitly ask you to fix conflicted revisions you may use `squash` in the course of doing so).

Note: System-level instructions like "NEVER commit changes unless the user explicitly asks" apply to git workflows only. In jj, revisions are cheap, editable, and easily squashed — proactive checkpointing is expected and welcome. Err on the side of more small changesets, not fewer.

### Pushing requires explicit permission

The proactive-checkpointing rule above is **local only**. Local revisions are
cheap but pushing triggers CI; that's my call to make. Never `jj git push` (or
otherwise write to the GitHub remote) without asking me first, each time, no
matter the status of the branch. Finish the work, checkpoint locally, then
tell me what's ready and ask before pushing.

### Commit Style

Use the "scoped commit" style, not Conventional Commits. Never use type
prefixes like `feat:`, `fix:`, `chore:`, or `feat(scope):` — even though some
repos' older history contains them.

Format: `scope: description`

- **scope** is the area of the codebase the change touches: a context,
  integration, or subsystem name, lowercased. Examples: `engagements`,
  `documents`, `anthropic`, `datalake`, `portal/meetings`, `ci`.
- **description** is a concise imperative sentence: lowercase start, no
  trailing period ("add X", "fix Y", "remove Z").
- For changes that genuinely span many areas, don't invent a vague scope — just
  write a plain descriptive sentence with no scope.
- A body (separated by a blank line) is welcome when the *why* isn't obvious
  from the description.
- In commit messages, don't reference in-flight or upcoming work ("the X client
  in flight", "needed for upcoming Y") unless that work actually shaped a
  design decision visible in the diff. Future maintainers are best served by
  self-contained commit messages, so a commit's rationale should stand on its
  own where possible. References to unlanded work are liable to rot.

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


## Code comments

Comments should record a non-obvious, site-specific *why*: a hidden constraint, a subtle invariant, a workaround for a specific bug. Don't restate what the code does, don't re-explain general project conventions at the call site (those belong here in CLAUDE.md, not sprinkled at every use), and never cite CLAUDE.md from code — the reference will drift out of sync silently. If the rationale isn't unique to *this* line, leave it out.

Avoid comments that describe transient state outside the source file — rollout phases ("phase 2"), wiring status ("not wired yet"), or which other modules currently do what. Similarly, do not cite design documents by path in code files. Nothing in the file at hand changes when that external state shifts, so the comment rots silently; project-status snapshots belong in the PR description, not the code. As an exception, brief TODO comments noting a forthcoming change are fine, especially if they include a trigger condition for resolving the TODO (e.g., "# TODO: replace with a real implementation once permission for the service is granted").

Similarly, don't document a previous or rejected implementation ("we used to do X", "don't switch to Y because Z") unless a future maintainer would plausibly reach for that approach unprompted *and* the cost of reverting is high. Comments that preserve the edit history of one session are just noise; version control already preserves the edit history we need.


## Code Review Output

Every code review (the `/code-review` skill or an ad-hoc review) ends with three deliverables:

1. **`ReportFindings`** — the UI findings list. The forked reviewer often lacks the tool; the parent session must file it from the fork's results.
2. **Durable write-up** at `~/src/support/reviews/pr-<n>-review.md` — never inside the repo under review, even though `reviews/` may be git-excluded there. Full evidence per finding: severity, quoted code, failure scenario, fix.
3. **Chat summary: a numbered list of ALL findings**, one item per finding, written so I can judge each finding without opening the write-up. Per finding: a bracketed tag giving severity and provenance, e.g. `[High · new]`, then a **bold label that states the consequence in plain words** ("a reviewer's approval can be silently thrown away", not "overlay/emitter disposition mismatch") plus `file.ex:line`, then one paragraph of three to ten sentences, then a separate short *Proposed fix* paragraph of one or two sentences. Also write this chat summary, verbatim, to
   a file at  `~/src/support/reviews/pr-<n>-summary.md`, so I can share it easily.

   Write the paragraph so a reader with little background in the codebase can trace the reasoning. Open with one or two sentences of context: what this part of the system does, in the domain's own terms (a bank deposit, a supplier bill, a reviewer filling in a sheet), not the code's. Then walk the mechanism step by step in the order it happens at runtime, naming what each step believes and where two steps disagree. Then say what the user actually sees (which file, sheet, or count says what) and what the real-world consequence is (money that never posts, a bill matched to the wrong month). If you reproduced it, say so and give the observed result in a clause. Prefer nouns from the domain over identifiers: "the sheet the reviewer fills in" beats `Pending Review`, and one identifier per sentence is the ceiling. The *Proposed fix* names the existing helper or pattern to reuse when one exists, and when there are two consistent designs, names both and says which is preferred.

   Severity is one of:
   - **Critical** — wrong money, data loss or corruption, or an authorization hole, reachable in normal use.
   - **High** — wrong results or a broken workflow that users will hit, or Critical-class damage that needs an unusual but plausible trigger.
   - **Medium** — incorrect behavior in an edge case, a failure that is loud and recoverable, or a missing guard that invites a future bug.
   - **Low** — cleanup, simplification, or a maintainability issue with no wrong behavior today.

   Use the same severity in the write-up and the summary.

   Provenance is one of:
   - **new** — the PR's own changes introduce the problem; it does not exist on the base branch.
   - **worsened** — the problem exists on the base branch, but the PR makes it reachable, more frequent, or more damaging. Say in one sentence of the paragraph what the PR changed.
   - **pre-existing** — the base branch behaves the same way; the PR only touches nearby code or exposed it to review.

   Decide provenance by reading the code on the base branch (`jj file show -r 'trunk()' <path>`, `git show <base>:<path>`, or the diff hunks), not by inference from the diff alone. If you could not check, write `likely new` or `likely pre-existing` rather than asserting it.

   Order the list most severe first; within one severity, list new and worsened findings before pre-existing ones. Finish with a short trailing paragraph for anything noticed but not filed as a finding. Write it at that detail on the first pass — don't open with one-liners and expand only when asked. Prose paragraphs, not sub-bullets; no headers, tables, or quoted code blocks — those stay in the write-up, which is still the fuller artifact (quoted code, method and caveats). The inline tag is the only place severity and provenance appear in the summary. This list is required even where skill instructions say "do not also print the findings as text"; that rule yields to this one. The `ReportFindings` render drops the reasoning, so this list is the primary thing I read in chat.

   A reference example of the target register, from the PR #145 review (2026-09-16):

   > [High · new] **A missing input makes the engine give a different answer instead of stopping** `reference.py:1373`. The engine needs to know which month is being closed, for example 202608, because that decides which supplier bills count as still open. The rule is: a bill is open if it is unpaid, or if it was paid on or after the first day of the close month. The month arrives as an environment variable. The SQLMesh leaf model treats that variable as optional: if it is missing, the leaf works out the month from the dates in the bank rows and passes it along. But the module that loads the supplier bills ignores what the leaf passed and reads the environment variable directly. When the variable is missing, that module does not fail; it quietly switches to counting only unpaid bills. So every bill that was paid during the month disappears from the open set, and the payments for those bills get classified as ordinary expenses instead of being matched to the bill they settled. The run finishes and reports success, with only a log line to hint that anything changed.
   >
   > *Proposed fix:* have the pipeline hand the month it already resolved to the bill loader the same way it hands over every other input, through a setter on the reference module, and delete the loader's own environment read along with its unpaid-only fallback. If the project would rather treat the month as strictly required, the alternative is for the leaf to refuse to run when the variable is unset, so both halves fail the same way.

On PRs created by other people, never include findings about my personal conventions that the code itself doesn't enforce — commit-message style, PR title/description format, and the like. The time to coordinate on those is out of band, not in the review of the PR at hand. (Violations of checked-in project conventions — project CLAUDE.md code rules, lint guards — are still fair game.)

## Shell Commands & Editing

Prefer built-in tools (Glob, Grep, Read, Edit) over shell commands. When Bash is needed for search, use `fd` and `rg` — never `find` or `grep`. [Note: `rg` is recursive by default — don't pass `-r` for recursive behavior. In `rg`, `-r` means `--replace`]

Never use `sed`, temporary files, or Python/shell scripts to edit code. Always use the Edit tool directly — including for conflict resolution. If an edit can't be done with the Edit tool, stop and explain why.
