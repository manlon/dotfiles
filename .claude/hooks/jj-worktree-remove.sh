#!/bin/bash
# WorktreeRemove hook — cleans up jj workspaces instead of git worktrees
set -euo pipefail

input=$(cat)
worktree_path=$(echo "$input" | jq -r '.worktree_path')
repo_root=$(echo "$input" | jq -r '.cwd')

cd "$repo_root"

workspace_name=$(basename "$worktree_path")
jj workspace forget "$workspace_name" 2>/dev/null || true
rm -rf "$worktree_path"
