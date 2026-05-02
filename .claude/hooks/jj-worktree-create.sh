#!/bin/bash
# WorktreeCreate hook — uses jj workspaces instead of git worktrees
set -euo pipefail

input=$(cat)
repo_root=$(echo "$input" | jq -r '.cwd // empty')
ws_name=$(echo "$input" | jq -r '.name // empty')

if [[ -z "$ws_name" || -z "$repo_root" ]]; then
  echo "ERROR: missing name or cwd in hook input" >&2
  echo "Input was: $input" >&2
  exit 1
fi

# Construct worktree path inside the repo's .claude/worktrees/ directory
worktree_path="${repo_root}/.claude/worktrees/${ws_name}"

cd "$repo_root"
mkdir -p "$(dirname "$worktree_path")"

# Forget any stale workspace with the same name
jj workspace forget "$ws_name" 2>/dev/null || true

# Create a jj workspace on top of the current working-copy parent
jj workspace add --name "$ws_name" "$worktree_path"

# Copy gitignored files needed for dev
for f in .env .env.local .claude/settings.local.json .claude/CLAUDE.local.md; do
  [ -f "$repo_root/$f" ] && cp "$repo_root/$f" "$worktree_path/$f"
done

echo "$worktree_path"
