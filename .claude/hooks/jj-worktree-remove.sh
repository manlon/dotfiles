#!/bin/bash
# WorktreeRemove hook — cleans up jj workspaces instead of git worktrees
set -euo pipefail

input=$(cat)
worktree_path=$(echo "$input" | jq -r '.worktree_path')
repo_root=$(echo "$input" | jq -r '.cwd')

cd "$repo_root"

workspace_name=$(basename "$worktree_path")

# If a .keep marker exists, preserve the worktree
if [[ -f "$worktree_path/.keep" ]]; then
  exit 0
fi

jj -R "$worktree_path" status > /dev/null
jj workspace forget "$workspace_name" 2>/dev/null || true
rm -rf "$worktree_path"
