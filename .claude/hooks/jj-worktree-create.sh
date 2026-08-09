#!/bin/bash
# WorktreeCreate hook — uses jj workspaces instead of git worktrees
set -euo pipefail

# Two invocation modes:
#   1. CLI:  jj-worktree-create.sh <name> [repo_root]
#   2. Hook: JSON on stdin with {cwd, name} (how Claude Code invokes it)
cli_mode=false
if [[ $# -ge 1 ]]; then
  cli_mode=true
  ws_name=$1
  # Default to the current workspace root so it works from anywhere in the repo.
  repo_root=${2:-$(jj workspace root 2>/dev/null || pwd)}
else
  input=$(cat)
  repo_root=$(echo "$input" | jq -r '.cwd // empty')
  ws_name=$(echo "$input" | jq -r '.name // empty')
fi

if [[ -z "$ws_name" || -z "$repo_root" ]]; then
  echo "ERROR: missing workspace name or repo root" >&2
  echo "Usage: $0 <name> [repo_root]   (or pass {cwd,name} JSON on stdin)" >&2
  exit 1
fi

# Outside a jj repo there is nothing to intercept: exit silently so Claude Code
# falls through to creating an ordinary git worktree. `jj root` rather than a
# test for .jj/ because repo_root is the hook's cwd, possibly a subdirectory.
if ! (cd "$repo_root" 2>/dev/null && jj root >/dev/null 2>&1); then
  exit 0
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
for f in .env .env.local .claude/settings.local.json; do
  [ -f "$repo_root/$f" ] && cp "$repo_root/$f" "$worktree_path/$f"
done

echo "$worktree_path"

if [[ "$cli_mode" == true ]]; then
  echo "Created workspace '$ws_name'. cd into it with:" >&2
  echo "  cd $worktree_path" >&2
fi
