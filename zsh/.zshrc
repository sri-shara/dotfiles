# ~/dotfiles/zsh/.zshrc — clean, fast, modular

DOTFILES="$HOME/dotfiles"

# Core zsh config
source "$DOTFILES/zsh/history.zsh"
source "$DOTFILES/zsh/completion.zsh"
source "$DOTFILES/zsh/aliases.zsh"
source "$DOTFILES/zsh/tools.zsh"

# Homebrew zsh plugins
if [ -d "$(brew --prefix 2>/dev/null)/share" ]; then
  _brew_prefix="$(brew --prefix)"
  [ -f "$_brew_prefix/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ] && \
    source "$_brew_prefix/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
  [ -f "$_brew_prefix/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ] && \
    source "$_brew_prefix/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
  unset _brew_prefix
fi

# Machine-specific overrides (not in version control)
[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"
export PATH="/Users/sri/Library/Python/3.13/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"

# Homebrew
eval "$(/opt/homebrew/bin/brew shellenv)"

# Go-installed tools (Task runner)
export PATH="$PATH:$HOME/go/bin"

# mise (tool version manager)
eval "$(mise activate zsh)"

# task shell completion
command -v task >/dev/null 2>&1 && eval "$(task --completion zsh)"
