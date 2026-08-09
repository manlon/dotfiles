#!/bin/bash
# WorktreeRemove hook — cleans up jj workspaces instead of git worktrees
set -euo pipefail

# Two invocation modes:
#   1. CLI:  jj-worktree-remove.sh <name> [repo_root]
#   2. Hook: JSON on stdin with {worktree_path, cwd} (how Claude Code invokes it)
cli_mode=false
if [[ $# -ge 1 ]]; then
  cli_mode=true
  workspace_name=$1
  # Default to the current workspace root so it works from anywhere in the repo.
  repo_root=${2:-$(jj workspace root 2>/dev/null || pwd)}
  worktree_path="${repo_root}/.claude/worktrees/${workspace_name}"
else
  input=$(cat)
  worktree_path=$(echo "$input" | jq -r '.worktree_path')
  repo_root=$(echo "$input" | jq -r '.cwd')
  workspace_name=$(basename "$worktree_path")
fi

if [[ -z "$workspace_name" || -z "$repo_root" ]]; then
  echo "ERROR: missing workspace name or repo root" >&2
  echo "Usage: $0 <name> [repo_root]   (or pass {worktree_path,cwd} JSON on stdin)" >&2
  exit 1
fi

# Outside a jj repo there is nothing to intercept: exit silently so Claude Code
# falls through to removing an ordinary git worktree.
if ! (cd "$repo_root" 2>/dev/null && jj root >/dev/null 2>&1); then
  exit 0
fi

cd "$repo_root"

# If a .keep marker exists, preserve the worktree
if [[ -f "$worktree_path/.keep" ]]; then
  [[ "$cli_mode" == true ]] && echo "Preserving '$workspace_name' (.keep marker present)" >&2
  exit 0
fi

# Snapshot the workspace's working copy if it still exists (no-op if already gone)
[[ -d "$worktree_path" ]] && jj -R "$worktree_path" status > /dev/null 2>&1 || true
jj workspace forget "$workspace_name" 2>/dev/null || true
rm -rf "$worktree_path"

[[ "$cli_mode" == true ]] && echo "Removed workspace '$workspace_name'" >&2
exit 0
