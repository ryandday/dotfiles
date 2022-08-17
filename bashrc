# Restore tmux
alias mux='pgrep -vx tmux > /dev/null && \
        tmux new -d -s delete-me && \
        tmux run-shell ~/.tmux/plugins/tmux-resurrect/scripts/restore.sh && \
        tmux kill-session -t delete-me && \
        tmux attach || tmux attach'

alias cpuhogs='ps wwaxr -o pid,stat,%cpu,time,command | head -10'

export FZF_DEFAULT_COMMAND='rg --files'
export CLICOLOR=1
export LSCOLORS=ExFxBxDxCxegedabagacad

# Fzf switch branches
alias gb="git branch -a -vv --color=always | grep -v '/HEAD\s' | fzf --height 100% --ansi --multi --tac | sed 's/^..//' | awk '{print $1}' | sed 's#^remotes/[^/]*/##' | xargs git checkout"

ta() {
  if [[ -z $TMUX ]]; then
    echo "Run with tmux"
  fi

  selected=$(find ~/repos -mindepth 1 -maxdepth 1 -type d | fzf)

  if [[ -z $selected ]]; then
      exit 0
  fi

  selected_name=$(basename "$selected" | tr . _)

  if ! tmux has-session -t=$selected_name 2> /dev/null; then
      tmux new-session -ds $selected_name -c $selected
      tmux send-keys -t $selected_name 'vim .' Enter
  fi

  tmux switch-client -t $selected_name
}


