PS1="%1~ %# "
export CLICOLOR=1
export LSCOLORS=ExGxBxDxCxEgEdxbxgxcxd
export FZF_DEFAULT_COMMAND='rg --files'
export REVIEW_BASE=main # Used in git aliases

if [[ $(uname -s) == "Darwin" ]]; then
  export PATH="/opt/homebrew/bin/:$PATH"
fi

# Restore tmux
alias mux='pgrep -vx tmux > /dev/null && \
  tmux new -d -s delete-me && \
  tmux run-shell ~/.tmux/plugins/tmux-resurrect/scripts/restore.sh && \
  tmux kill-session -t delete-me && \
  tmux attach || tmux attach'

# Only attach to tmux if we are not in a vscode terminal
if [[ "$TERM_PROGRAM" != "vscode" ]]; then
  # If we are not in tmux, either attach to current session or restore
  if [[ -z $TMUX ]]; then
    if [[ -n $(pgrep tmux) ]]; then
      tmux attach
    else
      tmux
    fi
  fi
fi

alias vim='nvim'
alias ls='ls --color=auto'
alias cpu='ps wwaxr -o pid,stat,%cpu,time,command | head -10'
alias path='echo -e ${PATH//:/\\n}' # Echo PATH with newlines

alias gb='git checkout $(git branch | fzf)'
alias gbr='git checkout --track $(git branch -r | fzf)'
alias gcha='git log --pretty=format: --name-only | sort | uniq -c | sort -rg | head -15'

source ~/.zsh_functions.zsh
bindkey -s '^o' 'lfcd\n'

# Package manager (path from brew installation)
if [[ "$(uname -s)" == "Darwin" ]]; then
  source /opt/homebrew/opt/antidote/share/antidote/antidote.zsh
elif [[ -f /etc/lsb-release ]] && grep -q "Ubuntu" /etc/lsb-release; then
  source /usr/share/zsh-antidote/antidote.zsh
fi

antidote load

# Set up zsh completion after loading packages
autoload -U +X compinit && compinit
autoload -U +X bashcompinit && bashcompinit
zstyle ':completion:*' menu select
# match LSCOLORS
zstyle ':completion:*' list-colors 'di=1;34:ln=1;36:so=1;31:pi=1;33:ex=1;32:bd=1;34;46:cd=1;34;43:su=0;41:sg=0;46:tw=0;42:ow=0;43'
zmodload zsh/complist
compinit
_comp_options+=(globdots) # Include hidden files.

# Use vim keys in tab complete menu:
bindkey -M menuselect 'h' vi-backward-char
bindkey -M menuselect 'k' vi-up-line-or-history
bindkey -M menuselect 'l' vi-forward-char
bindkey -M menuselect 'j' vi-down-line-or-history

