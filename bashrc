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
export LSCOLORS=ExFxBxDxCxegedabagacad
export REVIEW_BASE=main # Used in git aliases

# Used in tmux.conf to fuzzy find projects 
ta() {
  if [[ -z $TMUX ]]; then
    echo "Run with tmux"
    return 0
  fi

  selected=$(find ~/repos -mindepth 1 -maxdepth 1 -type d | fzf)

  if [[ -z $selected ]]; then
    return 0
  fi

  selected_name=$(basename "$selected" | tr . _)

  if ! tmux has-session -t=$selected_name 2> /dev/null; then
      tmux new-session -ds $selected_name -c $selected
      tmux send-keys -t $selected_name 'vim .' Enter
  fi

  tmux switch-client -t $selected_name
}

# Alias to execute filename of python file as module
# so that I can still use autocomplete
# It cuts the filename extension off and replaces "/" with "."
pm(){
    output=$(echo "$1" | sed -e "s/\//./g" -e "s/.py//g")
    python3 -m $output
}

