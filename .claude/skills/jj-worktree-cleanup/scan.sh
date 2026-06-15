#!/bin/bash
# Scan .claude/worktrees/ jj workspaces and classify each as in-use / keep / removable.
#
# A workspace is IN_USE if some live Claude Code session has its cwd inside the
# workspace path. Live sessions are read from ~/.claude/sessions/<pid>.json; a
# session only counts if its pid is still alive (stale files are ignored).
#
# Output: one tab-separated line per workspace — STATUS<TAB>name<TAB>path<TAB>detail
#   IN_USE  — a live session is working here; never touch
#   KEEP    — a .keep marker is present; preserve
#   REMOVE  — no live session, no marker; safe to forget + delete
#   ORPHAN  — directory on disk with no matching jj workspace; rm -rf only
set -euo pipefail

# Find the main repo's .claude/worktrees dir by walking up from $PWD. Works from
# the main checkout (finds its own) and from inside a workspace (the dir is an
# ancestor, since workspaces live under main/.claude/worktrees/<name>).
dir="$PWD"
worktrees=""
while [[ "$dir" != "/" ]]; do
  if [[ -d "$dir/.claude/worktrees" ]]; then
    worktrees="$dir/.claude/worktrees"
    break
  fi
  dir="$(dirname "$dir")"
done

if [[ -z "$worktrees" ]]; then
  echo "ERROR: no .claude/worktrees directory found above $PWD" >&2
  exit 1
fi

# Collect cwd of every live, alive session, newline-delimited (bash 3.2: no
# mapfile / safe associative arrays, so we keep these as newline strings).
live_cwds=""
for sf in "$HOME"/.claude/sessions/*.json; do
  [[ -f "$sf" ]] || continue
  pid=$(jq -r '.pid // empty' "$sf")
  cwd=$(jq -r '.cwd // empty' "$sf")
  [[ -n "$pid" && -n "$cwd" ]] || continue
  ps -p "$pid" >/dev/null 2>&1 || continue  # skip stale session files
  live_cwds="$live_cwds$cwd"$'\n'
done

# Known jj workspace names (excludes "default", which is the main checkout).
ws_names=$(jj workspace list 2>/dev/null | sed 's/:.*//' | grep -v '^default$' || true)
is_workspace() {
  printf '%s\n' "$ws_names" | grep -qx "$1"
}

in_use() {
  local path="$1" cwd
  while IFS= read -r cwd; do
    [[ -z "$cwd" ]] && continue
    [[ "$cwd" == "$path" || "$cwd" == "$path/"* ]] && return 0
  done <<< "$live_cwds"
  return 1
}

shopt -s nullglob
for path in "$worktrees"/*/; do
  path="${path%/}"
  name="$(basename "$path")"
  [[ "$name" == .* ]] && continue  # skip .claude and other dotfiles

  if ! is_workspace "$name"; then
    printf 'ORPHAN\t%s\t%s\t%s\n' "$name" "$path" "dir on disk, no jj workspace"
    continue
  fi
  if in_use "$path"; then
    printf 'IN_USE\t%s\t%s\t%s\n' "$name" "$path" "live session cwd here"
    continue
  fi
  if [[ -f "$path/.keep" ]]; then
    printf 'KEEP\t%s\t%s\t%s\n' "$name" "$path" ".keep marker present"
    continue
  fi
  # Snapshot the working copy into @ so nothing is lost, then describe @.
  jj -R "$path" status >/dev/null 2>&1 || true
  summary=$(jj -R "$path" log -r '@' --no-graph --ignore-working-copy \
    -T 'if(empty, "empty", "has changes") ++ " @ " ++ change_id.short()' 2>/dev/null || echo "unknown @")
  printf 'REMOVE\t%s\t%s\t%s\n' "$name" "$path" "$summary"
done
