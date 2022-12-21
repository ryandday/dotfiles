PS1="%1~ %# "
export CLICOLOR=1
export LSCOLORS=ExGxBxDxCxEgEdxbxgxcxd

# Restore tmux
alias mux='pgrep -vx tmux > /dev/null && \
  tmux new -d -s delete-me && \
  tmux run-shell ~/.tmux/plugins/tmux-resurrect/scripts/restore.sh && \
  tmux kill-session -t delete-me && \
  tmux attach || tmux attach'

alias cpuhogs='ps wwaxr -o pid,stat,%cpu,time,command | head -10'
alias path='echo -e ${PATH//:/\\n}' # Echo PATH with newlines

export FZF_DEFAULT_COMMAND='rg --files'
export REVIEW_BASE=main # Used in git aliases

source ~/.zsh_functions.zsh
bindkey -s '^o' 'lfcd\n'

# Package manager (location from brew installation)
source /usr/local/opt/antidote/share/antidote/antidote.zsh
antidote load

# Set up zsh completion after loading packages
autoload -U +X compinit && compinit
autoload -U +X bashcompinit && bashcompinit
zstyle ':completion:*' menu select
zmodload zsh/complist
compinit
_comp_options+=(globdots)		# Include hidden files.

# Use vim keys in tab complete menu:
bindkey -M menuselect 'h' vi-backward-char
bindkey -M menuselect 'k' vi-up-line-or-history
bindkey -M menuselect 'l' vi-forward-char
bindkey -M menuselect 'j' vi-down-line-or-history

