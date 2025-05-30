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

# Background function to update git status for prompt caching
update_git_status_cache() {
  local repo_path="$1"
  local cache_file="$2"
  
  # Ensure cache directory exists
  mkdir -p "$(dirname "$cache_file")"
  
  # Get git status
  local git_status=""
  local status_indicator=""
  
  if git rev-parse --git-dir > /dev/null 2>&1; then
    git_status=$(git status --porcelain 2>/dev/null)
    if [[ -n "$git_status" ]]; then
      status_indicator=" %F{red}●%f"
    else
      status_indicator=" %F{green}✓%f"
    fi
  fi
  
  # Write to cache with flock
  local timestamp=$(date +%s)
  local lock_fd
  exec {lock_fd}>"$cache_file.lock"
  if flock -x "$lock_fd"; then
    echo "$timestamp:$status_indicator" > "$cache_file"
    flock -u "$lock_fd"
  fi
  exec {lock_fd}>&-
}

# Git status function for prompt (reads from cache)
git_status_indicator() {
  # Check if we're in a git repository
  if ! git rev-parse --git-dir > /dev/null 2>&1; then
    return
  fi
  
  # Create cache file path based on repository
  local repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -z "$repo_root" ]]; then
    return
  fi
  
  local cache_file="$GIT_STATUS_CACHE_DIR/$(echo "$repo_root" | sed 's|/|_|g')"
  local current_time=$(date +%s)
  local should_update=false
  local status_indicator=""
  
  # Read from cache with flock
  if [[ -f "$cache_file" ]]; then
    local cache_content
    local lock_fd
    exec {lock_fd}>"$cache_file.lock"
    if flock -s "$lock_fd"; then
      cache_content=$(cat "$cache_file" 2>/dev/null)
      flock -u "$lock_fd"
    fi
    exec {lock_fd}>&-
    
    if [[ -n "$cache_content" ]]; then
      local cache_timestamp="${cache_content%%:*}"
      status_indicator="${cache_content#*:}"
      
      # Check if cache is expired
      if (( current_time - cache_timestamp > GIT_STATUS_TIMEOUT )); then
        should_update=true
      fi
    else
      should_update=true
    fi
  else
    should_update=true
  fi
  
  # Start background update if needed
  if [[ "$should_update" == "true" ]]; then
    # Start new background job (disown to prevent job control messages)
    (update_git_status_cache "$repo_root" "$cache_file" &)
  fi
  
  # Return cached status or empty if no cache yet
  echo "$status_indicator"
}

# Command execution time tracking
preexec() {
    timer=$(date +%s%N)
}

# Optimized precmd - always updates but fast
precmd() {
    # Always update vcs_info but it's configured to be fast
    vcs_info
    
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

# ==============================================
# MEMORY & CPU DEBUGGING ALIASES & FUNCTIONS
# ==============================================

# Memory Information
alias meminfo='free -h 2>/dev/null || vm_stat | head -10'
alias memtotal='echo "$(sysctl -n hw.memsize 2>/dev/null | awk "{print \$1/1024/1024/1024}") GB" 2>/dev/null || free -h | grep Mem | awk "{print \$2}"'
alias swapinfo='sysctl vm.swapusage 2>/dev/null || swapon -s 2>/dev/null || echo "No swap info available"'

# CPU Information  
alias cpuinfo='sysctl -n machdep.cpu.brand_string 2>/dev/null || cat /proc/cpuinfo | grep "model name" | head -1'
alias cpucores='sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo "CPU cores: Unknown"'
alias cpuload='uptime'

# Process Monitoring
alias psmem='ps aux | sort -k4 -nr | head -20'
alias pscpu='ps aux | sort -k3 -nr | head -20'
alias pstime='ps aux | sort -k10 -nr | head -20'

# Memory Usage by Process
memproc() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: memproc <process_name>"
        echo "Example: memproc chrome"
        return 1
    fi
    echo "Memory usage for processes matching '$1':"
    if [[ $(uname -s) == "Darwin" ]]; then
        ps aux | grep -i "$1" | grep -v grep | awk '{print $11 " " $4 "% " $6/1024 "MB"}' | sort -k3 -nr
    else
        ps aux | grep -i "$1" | grep -v grep | awk '{print $11 " " $4 "% " $6/1024 "MB"}' | sort -k3 -nr
    fi
}

# CPU Usage by Process
cpuproc() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: cpuproc <process_name>"
        echo "Example: cpuproc node"
        return 1
    fi
    echo "CPU usage for processes matching '$1':"
    ps aux | grep -i "$1" | grep -v grep | awk '{print $11 " " $3 "%"}' | sort -k2 -nr
}

# Kill processes by memory usage
killmem() {
    local threshold=${1:-80}
    echo "Finding processes using more than ${threshold}% memory..."
    if [[ $(uname -s) == "Darwin" ]]; then
        ps aux | awk -v thresh=$threshold '$4 > thresh {print $2, $11, $4"%"}' | while read pid cmd mem; do
            echo "Process: $cmd (PID: $pid) using $mem memory"
            read -q "REPLY?Kill this process? (y/n): "
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                kill $pid && echo "Killed $pid"
            fi
        done
    else
        ps aux | awk -v thresh=$threshold '$4 > thresh {print $2, $11, $4"%"}' | while read pid cmd mem; do
            echo "Process: $cmd (PID: $pid) using $mem memory"
            read -p "Kill this process? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                kill $pid && echo "Killed $pid"
            fi
        done
    fi
}

# Kill processes by CPU usage
killcpu() {
    local threshold=${1:-80}
    echo "Finding processes using more than ${threshold}% CPU..."
    ps aux | awk -v thresh=$threshold '$3 > thresh {print $2, $11, $3"%"}' | while read pid cmd cpu; do
        echo "Process: $cmd (PID: $pid) using $cpu CPU"
        if [[ $(uname -s) == "Darwin" ]]; then
            read -q "REPLY?Kill this process? (y/n): "
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                kill $pid && echo "Killed $pid"
            fi
        else
            read -p "Kill this process? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                kill $pid && echo "Killed $pid"
            fi
        fi
    done
}

# System Resource Summary
syssum() {
    echo "=== System Resource Summary ==="
    
    echo "\n--- CPU Information ---"
    cpuinfo
    echo "Cores: $(cpucores)"
    echo "Load: $(cpuload | awk -F': ' '{print $2}')"
    
    echo "\n--- Memory Information ---"
    if [[ $(uname -s) == "Darwin" ]]; then
        echo "Total Memory: $(memtotal)"
        echo "Memory Pressure: $(memory_pressure 2>/dev/null || echo "N/A")"
        vm_stat | head -5
    else
        free -h
    fi
    
    echo "\n--- Swap Information ---"
    swapinfo
    
    echo "\n--- Top CPU Processes ---"
    pscpu | head -5
    
    echo "\n--- Top Memory Processes ---"
    psmem | head -5
    
    echo "\n--- Disk Usage ---"
    df -h | head -5
}

# Memory pressure monitoring (macOS)
if [[ $(uname -s) == "Darwin" ]]; then
    mempressure() {
        echo "=== Memory Pressure Monitoring ==="
        echo "Press Ctrl+C to stop"
        while true; do
            local pressure=$(memory_pressure 2>/dev/null | head -1)
            local timestamp=$(date '+%H:%M:%S')
            echo "[$timestamp] $pressure"
            sleep 2
        done
    }
    
    # Memory statistics with breakdown
    memstat() {
        echo "=== Detailed Memory Statistics ==="
        
        # Get memory info
        local page_size=$(vm_stat | grep "page size" | awk '{print $8}')
        local pages_free=$(vm_stat | grep "Pages free" | awk '{print $3}' | tr -d '.')
        local pages_active=$(vm_stat | grep "Pages active" | awk '{print $3}' | tr -d '.')
        local pages_inactive=$(vm_stat | grep "Pages inactive" | awk '{print $3}' | tr -d '.')
        local pages_wired=$(vm_stat | grep "Pages wired down" | awk '{print $4}' | tr -d '.')
        local pages_compressed=$(vm_stat | grep "Pages stored in compressor" | awk '{print $5}' | tr -d '.')
        
        if [[ -n $page_size && -n $pages_free ]]; then
            echo "Page Size: $page_size bytes"
            echo "Free Memory: $(($pages_free * $page_size / 1024 / 1024)) MB"
            echo "Active Memory: $(($pages_active * $page_size / 1024 / 1024)) MB"
            echo "Inactive Memory: $(($pages_inactive * $page_size / 1024 / 1024)) MB"
            echo "Wired Memory: $(($pages_wired * $page_size / 1024 / 1024)) MB"
            echo "Compressed Memory: $(($pages_compressed * $page_size / 1024 / 1024)) MB"
        fi
        
        echo "\n--- Raw vm_stat Output ---"
        vm_stat
        
        echo "\n--- Memory Pressure ---"
        memory_pressure 2>/dev/null || echo "Memory pressure info not available"
    }
fi

# Memory leak detection
memleak() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: memleak <process_name> [interval_seconds]"
        echo "Example: memleak node 5"
        return 1
    fi
    
    local process_name=$1
    local interval=${2:-5}
    
    echo "=== Memory Leak Detection for '$process_name' ==="
    echo "Monitoring every $interval seconds. Press Ctrl+C to stop"
    echo "Time\t\tPID\tMemory(MB)\tChange"
    
    local prev_mem=0
    while true; do
        local timestamp=$(date '+%H:%M:%S')
        local process_info=$(ps aux | grep -i "$process_name" | grep -v grep | head -1)
        
        if [[ -n $process_info ]]; then
            local pid=$(echo $process_info | awk '{print $2}')
            local mem_kb=$(echo $process_info | awk '{print $6}')
            local mem_mb=$((mem_kb / 1024))
            
            local change=""
            if [[ $prev_mem -gt 0 ]]; then
                local diff=$((mem_mb - prev_mem))
                if [[ $diff -gt 0 ]]; then
                    change="+${diff}MB"
                elif [[ $diff -lt 0 ]]; then
                    change="${diff}MB"
                else
                    change="0MB"
                fi
            fi
            
            echo "$timestamp\t$pid\t${mem_mb}MB\t\t$change"
            prev_mem=$mem_mb
        else
            echo "$timestamp\tProcess '$process_name' not found"
        fi
        
        sleep $interval
    done
}

# Quick performance snapshot
perfsnap() {
    echo "=== Performance Snapshot $(date) ==="
    
    echo "\n--- System Load ---"
    uptime
    
    echo "\n--- CPU Usage ---"
    if [[ $(uname -s) == "Darwin" ]]; then
        top -l 1 -n 0 | grep "CPU usage"
    else
        top -bn1 | grep "Cpu(s)" | head -1
    fi
    
    echo "\n--- Memory Usage ---"
    if [[ $(uname -s) == "Darwin" ]]; then
        vm_stat | head -6
    else
        free -h
    fi
    
    echo "\n--- Disk I/O ---"
    if command -v iostat &> /dev/null; then
        iostat -d 1 1 | tail -n +4
    fi
    
    echo "\n--- Network ---"
    netstat -i | head -3
    
    echo "\n--- Top 5 CPU Processes ---"
    pscpu | head -6
    
    echo "\n--- Top 5 Memory Processes ---"
    psmem | head -6
}

# Performance monitoring for prompt
prompt_benchmark() {
    echo "Benchmarking prompt components..."
    
    # Test vcs_info
    echo -n "vcs_info: "
    time (vcs_info 2>/dev/null)
    
    # Test git_status function
    echo -n "git_status(): "
    time (git_status_indicator)
    
    # Test git operations individually
    echo -n "git rev-parse --is-inside-work-tree: "
    time (git rev-parse --is-inside-work-tree >/dev/null 2>&1)
    
    echo -n "git diff-index --quiet HEAD: "
    time (git diff-index --quiet HEAD -- 2>/dev/null)
    
    echo -n "git ls-files --others --exclude-standard: "
    time (git ls-files --others --exclude-standard 2>/dev/null >/dev/null)
    
    echo "\nFor comparison, the old slow method:"
    echo -n "git status --porcelain: "
    time (git status --porcelain 2>/dev/null >/dev/null)
}

aws_get_stack_info() {
  local service_pattern=""
  local task_pattern=""
  local container_pattern=""
  
  # First parameter is stack_name (required)
  local stack_name="$1"
  if [ -z "$stack_name" ]; then
    echo "Error: stack_name is required as first parameter"
    echo "Usage: get_stack_info <stack_name> [-s <service_pattern>] [-t <task_pattern>] [-c <container_pattern>]"
    return 1
  fi
  
  # Shift past stack_name
  shift
  
  # Parse command line options
  while getopts "s:t:c:" opt; do
    case ${opt} in
      s)
        service_pattern="$OPTARG"
        ;;
      t)
        task_pattern="$OPTARG"
        ;;
      c)
        container_pattern="$OPTARG"
        ;;
      \?)
        echo "Usage: get_stack_info <stack_name> [-s <service_pattern>] [-t <task_pattern>] [-c <container_pattern>]"
        return 1
        ;;
    esac
  done
  
  # Get the AWS region from the default profile or environment
  # local region=$(aws configure get region) # always us-east-1 right now
  if [ -z "$region" ]; then
    region="us-east-1"  # Default region if not configured
  fi

  # Get the stack URL
  local stack_url="https://console.aws.amazon.com/cloudformation/home?region=${region}#/stacks/stackinfo?stackId=${stack_name}"

  echo "└── Stack: ${stack_name}"
  echo "    🔗 ${stack_url}"

  # Get all ECS services from CloudFormation
  local services=$(aws cloudformation list-stack-resources \
    --stack-name "$stack_name" \
    --query "StackResourceSummaries[?ResourceType==\`AWS::ECS::Service\`].[LogicalResourceId,PhysicalResourceId]" \
    --output text)

  if [ -z "$services" ]; then
    echo "    ⚠️  No ECS services found in stack"
    return 1
  fi

  # Process each service
  echo "$services" | while read -r logical_id physical_id; do
    # Skip if service doesn't match the pattern (if a pattern was provided)
    if [ -n "$service_pattern" ] && ! echo "$logical_id" | grep -q "$service_pattern"; then
      continue
    fi

    # Extract cluster name and actual service name from ARN/PhysicalResourceId
    local cluster_name=$(echo "$physical_id" | sed -n 's/.*service\/\([^\/]*\)\/.*/\1/p')
    local actual_service_name=$(echo "$physical_id" | sed -n 's/.*\/\([^\/]*\)$/\1/p')

    if [ -z "$cluster_name" ] || [ -z "$actual_service_name" ]; then
      echo "    ⚠️  Could not extract cluster and service names from ARN: $physical_id"
      continue
    fi

    # Generate service URL
    local service_url="https://console.aws.amazon.com/ecs/home?region=${region}#/clusters/${cluster_name}/services/${actual_service_name}/details"

    echo "    └── Service: ${actual_service_name} (Cluster: ${cluster_name})"
    echo "        🔗 ${service_url}"

    # Get task ARNs
    local all_task_arns=$(aws ecs list-tasks \
      --cluster "$cluster_name" \
      --service-name "$actual_service_name" \
      --query 'taskArns[]' \
      --output text)

    if [ -n "$all_task_arns" ]; then
      # Process each task ARN individually
      for task_arn in $(echo "$all_task_arns" | tr '\t' '\n'); do
        # Skip empty lines
        [ -z "$task_arn" ] && continue

        # Extract the task ID from the ARN for display
        task_id=$(echo "$task_arn" | awk -F '/' '{print $NF}')
        
        # Skip if task doesn't match the pattern (if a pattern was provided)
        if [ -n "$task_pattern" ] && ! echo "$task_id" | grep -q "$task_pattern"; then
          continue
        fi

        # Generate task URL
        local task_url="https://console.aws.amazon.com/ecs/home?region=${region}#/clusters/${cluster_name}/tasks/${task_id}/details"

        # Get task details including container instance ID
        local task_details=$(aws ecs describe-tasks \
          --cluster "$cluster_name" \
          --tasks "$task_arn" \
          --output json)

        # Extract EC2 instance ARN
        local container_instance_arn=$(echo "$task_details" | jq -r '.tasks[0].containerInstanceArn // ""')

        # Get EC2 instance ID
        local ec2_instance_id=""
        if [ -n "$container_instance_arn" ]; then
          ec2_instance_id=$(aws ecs describe-container-instances \
            --cluster "$cluster_name" \
            --container-instances "$container_instance_arn" \
            --query 'containerInstances[0].ec2InstanceId' \
            --output text)
        fi

        # Get task status and task definition ARN
        local task_status=$(echo "$task_details" | jq -r '.tasks[0].lastStatus + " | " + (.tasks[0].healthStatus // "NONE")')
        local task_def_arn=$(echo "$task_details" | jq -r '.tasks[0].taskDefinitionArn')

        # Extract task definition name and revision
        local task_def_name=$(echo "$task_def_arn" | awk -F '/' '{print $NF}' | cut -d':' -f1)
        local task_def_revision=$(echo "$task_def_arn" | awk -F '/' '{print $NF}' | cut -d':' -f2)

        echo "        └── Task: ${task_id}"
        echo "            🔗 ${task_url}"
        echo "            📊 Status: ${task_status}"
        if [ -n "$ec2_instance_id" ]; then
          echo "            🖥️ EC2 Instance: ${ec2_instance_id}"
        fi

        # Get task definition details
        local task_def=$(aws ecs describe-task-definition \
          --task-definition "$task_def_arn" \
          --query 'taskDefinition' \
          --output json)

        # Get container details from the running task
        local containers=$(echo "$task_details" | jq -r '.tasks[0].containers')
        local container_count=$(echo "$containers" | jq 'length')
        local displayed_containers=0
        
        # Count how many containers we'll actually display (for correct tree formatting)
        if [ -n "$container_pattern" ]; then
          for ((i=0; i<$container_count; i++)); do
            local container_name=$(echo "$containers" | jq -r ".[$i].name")
            if echo "$container_name" | grep -q "$container_pattern"; then
              displayed_containers=$((displayed_containers+1))
            fi
          done
        else
          displayed_containers=$container_count
        fi

        # Process each container
        for ((i=0; i<$container_count; i++)); do
          # Get container details
          local container_name=$(echo "$containers" | jq -r ".[$i].name")
          
          # Skip if container doesn't match the pattern (if a pattern was provided)
          if [ -n "$container_pattern" ] && ! echo "$container_name" | grep -q "$container_pattern"; then
            continue
          fi
          
          local container_image=$(echo "$containers" | jq -r ".[$i].image")
          local container_status="$(echo "$containers" | jq -r ".[$i].lastStatus") | $(echo "$containers" | jq -r ".[$i].healthStatus // \"NONE\"")"

          # Tree prefix based on position - need to account for filtered containers
          displayed_containers=$((displayed_containers-1))
          if [ "$displayed_containers" -eq 0 ]; then
            prefix="            └── "
            log_prefix="                "
            ssm_log_prefix="                "
          else
            prefix="            ├── "
            log_prefix="            │   "
            ssm_log_prefix="                "
          fi

          echo "${prefix}Container: ${container_name}"
          echo "${log_prefix}📊 Status: ${container_status}"
          echo "${log_prefix}🐳 Image: $(echo $container_image | cut -d':' -f1):$(echo $container_image | cut -d':' -f2 | cut -c1-12)..."

          # Create SSM command to connect to container via EC2 instance if possible
          if [ -n "$ec2_instance_id" ]; then
            local docker_filter="task-$(echo $task_id | cut -c -8)"

            # Very simple, safe command that just shows container and returns to bash prompt
            local docker_grep_pattern="ecs-${task_def_name}-${task_def_revision}-${container_name}"
            # 🔌
            echo "${ssm_log_prefix} aws ssm start-session --region ${region} --target ${ec2_instance_id} --document-name AWS-StartInteractiveCommand --parameters '{\"command\":[\"CID=\$(sudo docker ps | grep ${docker_grep_pattern} | grep ${container_name} | head -n1 | cut -d\\\" \\\" -f1); if [ -n \$CID ]; then echo \\\"Connecting to container \$CID...\\\"; sudo docker exec -it \$CID /bin/bash || sudo docker exec -it \$CID /bin/sh; else echo \\\"Container not found\\\"; fi\"]}'"
          fi

          # Find the matching container definition in the task definition
          local log_config=$(echo "$task_def" | jq -r --arg name "$container_name" '.containerDefinitions[] | select(.name == $name).logConfiguration // {}')

          # Extract log group and stream prefix from task definition
          local log_driver=$(echo "$log_config" | jq -r '.logDriver // ""')

          # Extract and trim whitespace from log group and stream prefix
          local log_group=$(echo "$log_config" | jq -r '.options."awslogs-group" // ""' | xargs)
          local log_stream_prefix=$(echo "$log_config" | jq -r '.options."awslogs-stream-prefix" // ""' | xargs)

          if [ -n "$log_group" ]; then
            # Construct the CloudWatch logs URL
            local log_stream="${log_stream_prefix}/${container_name}/${task_id}"

            # Trim whitespace and encode URL components
            local encoded_log_group=$(echo "$log_group" | xargs | sed 's/\//%2F/g')
            local encoded_log_stream=$(echo "$log_stream" | xargs | sed 's/\//%2F/g')

            local logs_url="https://console.aws.amazon.com/cloudwatch/home?region=${region}#logsV2:log-groups/log-group/${encoded_log_group}/log-events/${encoded_log_stream}"

            echo "${log_prefix}📝 Logs: ${log_group}/${log_stream}"
            echo "${log_prefix}🔗 ${logs_url}"
          else
            echo "${log_prefix}📝 Logs: CloudWatch logs configured but no log group specified"
          fi
        done
      done
    else
      echo "        └── No running tasks found for this service"
    fi
  done
}

# Quick access to stack events
aws_stack_events() {
  local stack_name=$1
  local limit=${2:-20}

  if [[ -z "$stack_name" ]]; then
    echo "Usage: aws_stack_events STACK_NAME [LIMIT]"
    return 1
  fi

  aws cloudformation describe-stack-events --stack-name $stack_name \
    --query "StackEvents[0:$limit].{Timestamp:Timestamp,LogicalId:LogicalResourceId,Status:ResourceStatus,Reason:ResourceStatusReason}" \
    --output table
}
