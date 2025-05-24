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

# ==============================================
# NETWORK DEBUGGING ALIASES & FUNCTIONS
# ==============================================

# Port and Process Debugging
alias ports='netstat -tulanp'
alias listening='lsof -iTCP -sTCP:LISTEN -n -P'
alias portslocal='lsof -nP -iTCP -sTCP:LISTEN | grep LISTEN'
alias connections='lsof -iTCP -sTCP:ESTABLISHED -n -P'

# Quick port check for common services
alias check-http='lsof -i :80'
alias check-https='lsof -i :443'
alias check-ssh='lsof -i :22'

# Check what's running on a specific port
port() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: port <port_number>"
        return 1
    fi
    echo "Checking what's running on port $1..."
    lsof -i :$1
}

# Kill process running on specific port
killport() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: killport <port_number>"
        return 1
    fi
    echo "Killing process on port $1..."
    lsof -ti:$1 | xargs kill -9
}

# Network Interface Information
alias interfaces='ifconfig | grep -E "^[a-z]|inet "'
alias myip='curl -s https://ipinfo.io/ip'
alias localip='ipconfig getifaddr en0 2>/dev/null || hostname -I 2>/dev/null | cut -d" " -f1'
alias gateway='route -n get default | grep gateway'

# DNS Debugging
dnscheck() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: dnscheck <domain>"
        return 1
    fi
    echo "DNS lookup for $1:"
    nslookup $1
    echo "\nDig output:"
    dig $1
}

# Test DNS resolution time
dnstime() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: dnstime <domain>"
        return 1
    fi
    echo "Testing DNS resolution time for $1..."
    time nslookup $1 > /dev/null
}

# Connectivity Testing
pingtest() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: pingtest <host> [count]"
        return 1
    fi
    local count=${2:-5}
    echo "Pinging $1 ($count times)..."
    ping -c $count $1
}

# Test TCP connectivity
tcptest() {
    if [[ $# -lt 2 ]]; then
        echo "Usage: tcptest <host> <port>"
        return 1
    fi
    echo "Testing TCP connection to $1:$2..."
    if command -v nc &> /dev/null; then
        nc -zv $1 $2
    elif command -v telnet &> /dev/null; then
        timeout 5 telnet $1 $2
    else
        echo "Neither nc nor telnet available"
        return 1
    fi
}

# HTTP/HTTPS Testing
httptest() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: httptest <url>"
        return 1
    fi
    echo "Testing HTTP connectivity to $1..."
    curl -I -s --connect-timeout 10 $1
}

# Test HTTP with timing
httptime() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: httptime <url>"
        return 1
    fi
    echo "Testing HTTP timing for $1..."
    curl -o /dev/null -s -w "Time: %{time_total}s | DNS: %{time_namelookup}s | Connect: %{time_connect}s | Transfer: %{time_starttransfer}s | Size: %{size_download} bytes\n" $1
}

# Test HTTPS certificate
ssltest() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: ssltest <domain> [port]"
        return 1
    fi
    local port=${2:-443}
    echo "Testing SSL certificate for $1:$port..."
    echo | openssl s_client -servername $1 -connect $1:$port 2>/dev/null | openssl x509 -noout -dates -subject -issuer
}

# Network Route Debugging
traceroute() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: traceroute <host>"
        return 1
    fi
    echo "Tracing route to $1..."
    if command -v traceroute &> /dev/null; then
        command traceroute $1
    elif command -v tracert &> /dev/null; then
        tracert $1
    else
        echo "No traceroute command available"
        return 1
    fi
}

# Bandwidth Testing
speedtest() {
    if command -v curl &> /dev/null; then
        echo "Testing download speed..."
        curl -o /dev/null -s -w "Download Speed: %{speed_download} bytes/sec (%{speed_download_avg} avg)\n" \
        http://speedtest.tele2.net/10MB.zip
    else
        echo "curl not available for speed test"
        return 1
    fi
}

# Network Security Scanning (basic)
portscan() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: portscan <host> [start_port] [end_port]"
        return 1
    fi
    local host=$1
    local start=${2:-1}
    local end=${3:-1000}
    
    echo "Scanning ports $start-$end on $host..."
    for ((port=$start; port<=$end; port++)); do
        if nc -z -w1 $host $port 2>/dev/null; then
            echo "Port $port: Open"
        fi
    done
}

# Docker Network Debugging
dockernet() {
    echo "Docker network information:"
    echo "\n--- Docker Networks ---"
    docker network ls
    echo "\n--- Container Network Details ---"
    docker ps --format "table {{.Names}}\t{{.Ports}}\t{{.Status}}"
}

# Docker container connectivity test
dockerping() {
    if [[ $# -lt 2 ]]; then
        echo "Usage: dockerping <container1> <container2>"
        return 1
    fi
    echo "Testing connectivity from $1 to $2..."
    docker exec $1 ping -c 3 $2
}

# Network Monitoring
netmon() {
    local interface=${1:-$(route get default | grep interface | awk '{print $2}')}
    echo "Monitoring network activity on interface $interface..."
    echo "Press Ctrl+C to stop"
    if command -v iftop &> /dev/null; then
        sudo iftop -i $interface
    elif command -v nethogs &> /dev/null; then
        sudo nethogs $interface
    else
        echo "Install iftop or nethogs for network monitoring"
        netstat -i 1
    fi
}

# Quick network summary
netsum() {
    echo "=== Network Summary ==="
    echo "\n--- Local IP ---"
    localip
    echo "\n--- Gateway ---"
    gateway
    echo "\n--- Active Connections ---"
    netstat -tn | grep ESTABLISHED | wc -l | xargs echo "Established connections:"
    echo "\n--- Listening Ports ---"
    netstat -tln | grep LISTEN | wc -l | xargs echo "Listening ports:"
    echo "\n--- DNS Servers ---"
    if [[ -f /etc/resolv.conf ]]; then
        grep nameserver /etc/resolv.conf
    fi
}

# WiFi information (macOS specific)
if [[ $(uname -s) == "Darwin" ]]; then
    # Modern WiFi diagnostics using wdutil
    alias wifi='wdutil info'
    alias wifiscan='wdutil scan'
    alias wifilog='wdutil diagnose'
    
    # WiFi connection details
    wifidetails() {
        echo "=== WiFi Connection Details ==="
        echo "\n--- Basic Info ---"
        wdutil info | grep -E "(SSID|BSSID|Channel|Signal|Noise|CC|Security)"
        
        echo "\n--- Network Preferences ---"
        networksetup -getairportnetwork en0 2>/dev/null || networksetup -getairportnetwork en1 2>/dev/null
        
        echo "\n--- Airport Power ---"
        networksetup -getairportpower en0 2>/dev/null || networksetup -getairportpower en1 2>/dev/null
    }
    
    # WiFi quality check
    wifiquality() {
        echo "=== WiFi Quality Assessment ==="
        wdutil info | grep -E "(Signal|Noise|RSSI|SNR|Channel)" | while IFS= read -r line; do
            if [[ $line == *"Signal"* ]]; then
                signal=$(echo $line | grep -o '\-[0-9]*' | head -1)
                if [[ -n $signal ]]; then
                    if [[ $signal -gt -50 ]]; then
                        echo "$line (Excellent)"
                    elif [[ $signal -gt -60 ]]; then
                        echo "$line (Good)"
                    elif [[ $signal -gt -70 ]]; then
                        echo "$line (Fair)"
                    else
                        echo "$line (Poor)"
                    fi
                else
                    echo "$line"
                fi
            else
                echo "$line"
            fi
        done
    }
    
    # WiFi troubleshooting
    wififix() {
        echo "=== WiFi Troubleshooting ==="
        echo "1. Checking WiFi status..."
        networksetup -getairportpower en0 2>/dev/null || networksetup -getairportpower en1 2>/dev/null
        
        echo "\n2. Checking network connectivity..."
        ping -c 3 8.8.8.8 > /dev/null 2>&1
        if [[ $? -eq 0 ]]; then
            echo "✅ Internet connectivity: OK"
        else
            echo "❌ Internet connectivity: Failed"
        fi
        
        echo "\n3. Checking DNS resolution..."
        nslookup google.com > /dev/null 2>&1
        if [[ $? -eq 0 ]]; then
            echo "✅ DNS resolution: OK"
        else
            echo "❌ DNS resolution: Failed"
        fi
        
        echo "\n4. Current WiFi quality:"
        wifiquality
        
        echo "\n💡 Quick fixes to try:"
        echo "   - Toggle WiFi: sudo networksetup -setairportpower en0 off && sudo networksetup -setairportpower en0 on"
        echo "   - Renew DHCP: sudo ipconfig set en0 DHCP"
        echo "   - Flush DNS: sudo dscacheutil -flushcache"
        echo "   - Reset network settings: sudo networksetup -detectnewhardware"
    }
    
    # List nearby WiFi networks with signal strength
    wifilist() {
        echo "=== Nearby WiFi Networks ==="
        wdutil scan | grep -E "(SSID|Signal|Channel|Security)" | 
        awk 'BEGIN{print "SSID\t\t\tSignal\tChannel\tSecurity"} 
             /SSID/{ssid=$2} 
             /Signal/{signal=$2} 
             /Channel/{channel=$2} 
             /Security/{security=$2; print ssid"\t\t"signal"\t"channel"\t"security; ssid=""; signal=""; channel=""; security=""}'
    }
fi
