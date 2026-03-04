# Starship prompt
command -v starship &>/dev/null && eval "$(starship init zsh)"

# fzf keybindings and completion (Ctrl-R, Ctrl-T)
command -v fzf &>/dev/null && eval "$(fzf --zsh)"

# zoxide (smart cd)
command -v zoxide &>/dev/null && eval "$(zoxide init zsh)"

# mise (runtime manager — replaces nvm)
command -v mise &>/dev/null && eval "$(mise activate zsh)"

# direnv (per-directory env vars)
command -v direnv &>/dev/null && eval "$(direnv hook zsh)"

# Go
if command -v go &>/dev/null; then
  export PATH="$PATH:$(go env GOPATH)/bin"
fi

# Google Cloud SDK
if [ -f "$HOME/command-center/server/yes/google-cloud-sdk/path.zsh.inc" ]; then
  source "$HOME/command-center/server/yes/google-cloud-sdk/path.zsh.inc"
fi
if [ -f "$HOME/command-center/server/yes/google-cloud-sdk/completion.zsh.inc" ]; then
  source "$HOME/command-center/server/yes/google-cloud-sdk/completion.zsh.inc"
fi
