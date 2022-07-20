
# Restore tmux
alias mux='pgrep -vx tmux > /dev/null && \
        tmux new -d -s delete-me && \
        tmux run-shell ~/.tmux/plugins/tmux-resurrect/scripts/restore.sh && \
        tmux kill-session -t delete-me && \
        tmux attach || tmux attach'

export FZF_DEFAULT_COMMAND='rg --files'
export CLICOLOR=1
export LSCOLORS=ExFxBxDxCxegedabagacad
