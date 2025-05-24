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

# Use lf to switch directories 
lfcd () {
    tmp="$(mktemp)"
    lf -last-dir-path="$tmp" "$@"
    if [ -f "$tmp" ]; then
        dir="$(cat "$tmp")"
        rm -f "$tmp"
        [ -d "$dir" ] && [ "$dir" != "$(pwd)" ] && cd "$dir"
    fi
}

# Command execution time tracking
preexec() {
    timer=$(date +%s%N)
}

precmd() {
    vcs_info  # Keep existing vcs_info call
    
    if [ $timer ]; then
        local now=$(date +%s%N)
        local elapsed=$(((now-timer)/1000000))
        
        if [ $elapsed -gt 1000 ]; then
            export RPS1="%F{yellow}⚡${elapsed}ms%f %F{240}%n@%m%f"
        else
            export RPS1='%F{240}%n@%m%f'
        fi
        unset timer
    fi
}

# Quick directory navigation
..() {
    cd ..
}

...() {
    cd ../..
}

....() {
    cd ../../..
}

# Enhanced ls with icons (if you have exa/eza installed)
if command -v eza &> /dev/null; then
    alias ls='eza --icons --group-directories-first'
    alias ll='eza -la --icons --group-directories-first'
    alias lt='eza --tree --level=2 --icons'
elif command -v exa &> /dev/null; then
    alias ls='exa --icons --group-directories-first'
    alias ll='exa -la --icons --group-directories-first'
    alias lt='exa --tree --level=2 --icons'
fi

# Better cat with syntax highlighting
if command -v bat &> /dev/null; then
    alias cat='bat --paging=never'
    alias bcat='bat'  # Keep original bat command available
fi

# Modern find replacement  
if command -v fd &> /dev/null; then
    alias find='fd'
    alias oldfind='command find'  # Keep original find available
fi

# Better top replacement
if command -v btop &> /dev/null; then
    alias top='btop'
    alias htop='btop'
fi

# Git enhanced functions
gst() {
    git status --short --branch
}

glog() {
    git log --oneline --graph --decorate --all -10
}
