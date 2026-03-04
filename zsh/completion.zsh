autoload -Uz compinit && compinit -C

setopt MENU_COMPLETE      # Auto-select first match
setopt AUTO_MENU          # Show completion menu on tab
setopt COMPLETE_IN_WORD   # Complete from both ends of word

# Case-insensitive matching
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# Completion menu with selection
zstyle ':completion:*' menu select

# Group completions by type
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{yellow}-- %d --%f'
