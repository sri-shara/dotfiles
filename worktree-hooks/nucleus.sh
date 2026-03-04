#!/bin/bash
# Nucleus-specific worktree setup
# Called by create-worktree with: $1 = main_worktree, $2 = new_worktree

main_worktree="$1"
new_worktree="$2"

# Copy frontend .env if the directory exists
if [ -d "$main_worktree/frontend/nucleus-app" ]; then
  mkdir -p "$new_worktree/frontend/nucleus-app"
  if [ -f "$main_worktree/frontend/nucleus-app/.env" ]; then
    cp "$main_worktree/frontend/nucleus-app/.env" "$new_worktree/frontend/nucleus-app/.env"
    echo "  Copied frontend/nucleus-app/.env"
  fi
  if [ -f "$main_worktree/frontend/nucleus-app/.env.local" ]; then
    cp "$main_worktree/frontend/nucleus-app/.env.local" "$new_worktree/frontend/nucleus-app/.env.local"
    echo "  Copied frontend/nucleus-app/.env.local"
  fi
fi

# Copy credentials (service account keys)
if [ -d "$main_worktree/credentials" ]; then
  mkdir -p "$new_worktree/credentials"
  cp "$main_worktree/credentials/"*.json "$new_worktree/credentials/" 2>/dev/null
  count=$(ls "$new_worktree/credentials/"*.json 2>/dev/null | wc -l | tr -d ' ')
  echo "  Copied $count credential file(s)"
fi
