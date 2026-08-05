---
name: pr-description
description: Write a PR title and description for a branch. Use when asked to draft a PR title, description, or body text.
---

# PR Descriptions

The audience is a human reviewer who is about to read the diff. The
description's only job is to get them oriented quickly and to flag anything
that would otherwise surprise them mid-review. It is not documentation, not a
changelog, and never detailed enough to re-implement the change — the diff
itself is the source of truth for what changed.

## The test for every sentence

Cut any sentence that doesn't either (a) orient the reviewer before they read
the code, or (b) prevent a "wait, why is this here?" moment when they hit
something unexpected. If it merely summarizes what the diff plainly shows, it
fails the test. Beyond a few dozen words, the odds the reviewer reads — or can
later find — any given sentence drop toward zero.

## Shape

- One or two opening sentences: what the change is and why it exists.
- Then reviewer notes, but **only if there are genuine surprises** to flag:
  - behavioral changes beyond the headline feature (especially ones that
    affect existing functionality)
  - data/migration implications, rollout or revert concerns
  - intentional weirdness the reviewer would otherwise flag as a mistake
  - scope boundaries — what is deliberately *not* done here
  It's fine (common even) to have no such notes or just one bullet point. Don't
  pad this section just to look complete.
- Title follows the commit-message convention for the repo (for this user:
  `scope: imperative description`, no type prefixes).

## Style

- Bullets over prose. Minimal markdown: no section headers, no bold-label
  bullets, no emoji, no horizontal rules.
- Describe concepts, not file/module inventory. The diff already shows names.
  Exception: one "start reading here" anchor is fine for a large refactor.
- Thorough testing is the default assumption — never list what's tested.
  Call out only the absence of tests or an unusual testing approach.
- Same for other expected states: don't say it follows conventions, compiles,
  or passes CI.

## Example

Here is an example PR description taken from a branch that added a second
workflow domain by extracting shared machinery (~2,600 lines). Note it would not
be surprising to have fewer or more notes if warranted; the target is genuine
call-outs, not a particular length or shape of the PR description.

```
rollforward: add AR reserves as a second workflow domain

Adds the AR reserves workflow roll-forward alongside leases. The two share a
five-step shape, so the leases transform action and portal domain module become
shared config-driven implementations and AR plugs in as configuration.

Notes:
- JE artifacts are now categorized :journal_entry instead of :workpaper
  (leases too) — fixes finalize JEs being carried forward as phantom inputs
  next period. (JEs from already-completed runs won't be updated — consider a
  one-off data migration if any exist in prod.)
- on_reject may now point at the item itself; both built-ins use this so
  rejecting at the upload step lets you retry without redoing the more
  expensive previous steps.
- Run creation is manual (iex) for v1; scheduled triggering is out of scope.
```
