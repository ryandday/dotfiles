# Enhanced custom prompt with git integration
autoload -Uz vcs_info
zstyle ':vcs_info:git:*' formats ' on %F{magenta}%b%f'
zstyle ':vcs_info:*' enable git
setopt PROMPT_SUBST

# Function to get git status
git_status() {
    if git rev-parse --git-dir > /dev/null 2>&1; then
        local git_state=""
        # Check for changes
        if [[ -n $(git status --porcelain) ]]; then
            git_state=" %F{red}●%f"
        else
            git_state=" %F{green}✓%f"
        fi
        echo $git_state
    fi
}

# Enhanced multi-line prompt
PS1='
%F{cyan}╭─%f %F{blue}%~%f%F{yellow}${vcs_info_msg_0_}%f$(git_status) %F{magenta}[%*]%f
%F{cyan}╰─%f %F{green}❯%f '

# Initial right-side prompt (will be updated by functions)
RPS1='%F{240}%n@%m%f'

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

# Quick file operations
alias grep='grep --color=auto'
alias mkdir='mkdir -pv'  # Create parent directories and be verbose
alias cp='cp -i'         # Confirm before overwriting
alias mv='mv -i'         # Confirm before overwriting
alias rm='rm -i'         # Confirm before removing

# Network and system
alias df='df -H'
alias du='du -ch'

alias gb='git checkout $(git branch | fzf)'
alias gbr='git checkout --track $(git branch -r | fzf)'
alias gcha='git log --pretty=format: --name-only | sort | uniq -c | sort -rg | head -15'

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

# Enhanced history settings
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history
setopt SHARE_HISTORY         # Share history between all sessions
setopt HIST_EXPIRE_DUPS_FIRST # Expire a duplicate event first when trimming history
setopt HIST_IGNORE_DUPS      # Do not record an event that was just recorded again
setopt HIST_IGNORE_ALL_DUPS  # Delete an old recorded event if a new event is a duplicate
setopt HIST_FIND_NO_DUPS     # Do not display a previously found event
setopt HIST_IGNORE_SPACE     # Do not record an event starting with a space
setopt HIST_SAVE_NO_DUPS     # Do not write a duplicate event to the history file
setopt HIST_VERIFY           # Do not execute immediately upon history expansion

# Enable auto-correction and suggestions
setopt CORRECT               # Correct commands
setopt AUTO_CD               # Auto cd when typing directory name
setopt AUTO_PUSHD            # Make cd push the old directory onto the directory stack
setopt PUSHD_IGNORE_DUPS     # Don't push multiple copies of the same directory

# Enhanced keyboard shortcuts
bindkey '^[[A' history-substring-search-up     # Up arrow for history search
bindkey '^[[B' history-substring-search-down   # Down arrow for history search
bindkey '^[[1;5C' forward-word                 # Ctrl+Right arrow
bindkey '^[[1;5D' backward-word                # Ctrl+Left arrow
bindkey '^H' backward-kill-word                # Ctrl+Backspace
bindkey '^[[3;5~' kill-word                    # Ctrl+Delete

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

