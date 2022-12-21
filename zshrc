PS1="%1~ %# "

# Display git branch on right hand prompt
autoload -Uz vcs_info
precmd_vcs_info() { vcs_info }
precmd_functions+=( precmd_vcs_info )
setopt prompt_subst
RPROMPT=\$vcs_info_msg_0_
zstyle ':vcs_info:git:*' formats '( %b )'
zstyle ':vcs_info:*' enable git

# Restore tmux
alias mux='pgrep -vx tmux > /dev/null && \
        tmux new -d -s delete-me && \
        tmux run-shell ~/.tmux/plugins/tmux-resurrect/scripts/restore.sh && \
        tmux kill-session -t delete-me && \
        tmux attach || tmux attach'

alias cpuhogs='ps wwaxr -o pid,stat,%cpu,time,command | head -10'
alias path='echo -e ${PATH//:/\\n}' # Echo PATH with newlines

export FZF_DEFAULT_COMMAND='rg --files'
export CLICOLOR=1
export REVIEW_BASE=main # Used in git aliases

# Package manager (installed with brew)
source /usr/local/opt/antidote/share/antidote/antidote.zsh
antidote load

