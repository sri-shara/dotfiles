#!/bin/bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"

echo "Installing dotfiles from $DOTFILES"
echo ""

# --- Homebrew ---
if ! command -v brew &>/dev/null; then
  echo "Error: Homebrew not found. Install it first: https://brew.sh"
  exit 1
fi

echo "Installing brew packages..."
brew bundle --file="$DOTFILES/Brewfile"

# --- mise: Node.js ---
if command -v mise &>/dev/null; then
  echo ""
  echo "Setting up Node.js via mise..."
  mise use --global node@22
fi

# --- Symlinks ---
echo ""
echo "Creating symlinks..."

# .zshrc
ln -sf "$DOTFILES/zsh/.zshrc" "$HOME/.zshrc"
echo "  zsh/.zshrc -> ~/.zshrc"

# Ghostty
mkdir -p "$HOME/.config/ghostty"
ln -sf "$DOTFILES/ghostty/config" "$HOME/.config/ghostty/config"
echo "  ghostty/config -> ~/.config/ghostty/config"

# Starship
mkdir -p "$HOME/.config"
ln -sf "$DOTFILES/starship/starship.toml" "$HOME/.config/starship.toml"
echo "  starship/starship.toml -> ~/.config/starship.toml"

# Claude Code user settings (hooks, plugins, effort level)
mkdir -p "$HOME/.claude"
ln -sf "$DOTFILES/claude/settings.json" "$HOME/.claude/settings.json"
echo "  claude/settings.json -> ~/.claude/settings.json"

# --- Scripts ---
chmod +x "$DOTFILES/bin/"*
echo ""
echo "Done. Open a new terminal to start using the new config."
