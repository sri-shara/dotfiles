# Worktree management
alias create-worktree="$HOME/dotfiles/bin/create-worktree"
alias wtc="create-worktree"
alias wt="git worktree list"
alias wtr="git worktree remove"
alias wtp='cd $(git worktree list | fzf --height=40% | awk "{print \$1}")'

# Modern tool replacements (only if installed)
command -v eza &>/dev/null && alias ls="eza --icons --group-directories-first"
command -v bat &>/dev/null && alias cat="bat --style=plain"
command -v fd  &>/dev/null && alias find="fd"

# Common shortcuts
alias ..="cd .."
alias ...="cd ../.."
alias g="git"
alias gs="git status"
alias gd="git diff"
alias gl="git log --oneline -20"
