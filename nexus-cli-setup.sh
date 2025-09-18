#!/bin/bash
set -e

# === Basic Configuration ===
BASE_CONTAINER_NAME="nexus-node"
IMAGE_NAME="nexus-node:latest"

# Cross-platform home directory detection
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ -n "$WINDIR" ]]; then
    # Windows environment - use proper Windows home path
    LOG_DIR="$HOME/nexus_logs"
else
    # Linux environment
    LOG_DIR="/home/$(whoami)/nexus_logs"
fi

WALLET_SAVE_FILE="${LOG_DIR}/.saved_wallet"  # File to store the last used wallet address

# === Terminal Colors ===
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

# === Header Display ===
function show_header() {
    clear
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${GREEN}||      ||  || ||   ||   || || ====="
    echo -e "${RED}||  /\  ||  || ||   ||   || || ||==="
    echo -e "${GREEN}|| //\\  ||  || ||== ||== || || ====="
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "    NEXUS SUPER NODE BY WILLIE_BULLISH"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

# === Ensure Docker is Available ===
function ensure_docker_available() {
    # Quick check if docker command is available
    if command -v docker >/dev/null 2>&1; then
        return 0
    fi
    
    # On Windows, try to find and add Docker to PATH
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ -n "$WINDIR" ]]; then
        # Check common Docker Desktop installation paths
        DOCKER_PATHS=(
            "/c/Program Files/Docker/Docker/resources/bin/docker.exe"
            "/c/Program Files (x86)/Docker/Docker/resources/bin/docker.exe"
            "$HOME/AppData/Local/Programs/Docker/Docker/resources/bin/docker.exe"
        )
        
        for docker_path in "${DOCKER_PATHS[@]}"; do
            if [ -f "$docker_path" ]; then
                export PATH="$(dirname "$docker_path"):$PATH"
                return 0
            fi
        done
    fi
    
    # If we get here, Docker is not found
    echo -e "${RED}❌ Docker command not found. Please ensure Docker is running.${RESET}"
    return 1
}

# === Check Docker Installation ===
function check_docker() {
    # First check if docker command is available
    if ! command -v docker >/dev/null 2>&1; then
        
        # On Windows, check if Docker Desktop is installed but not in PATH
        if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ -n "$WINDIR" ]]; then
            # Check common Docker Desktop installation paths
            DOCKER_PATHS=(
                "/c/Program Files/Docker/Docker/resources/bin/docker.exe"
                "/c/Program Files (x86)/Docker/Docker/resources/bin/docker.exe"
                "$HOME/AppData/Local/Programs/Docker/Docker/resources/bin/docker.exe"
            )
            
            for docker_path in "${DOCKER_PATHS[@]}"; do
                if [ -f "$docker_path" ]; then
                    echo -e "${GREEN}✅ Found Docker Desktop at: $docker_path${RESET}"
                    echo -e "${CYAN}📋 Adding Docker to PATH for this session...${RESET}"
                    export PATH="$(dirname "$docker_path"):$PATH"
                    
                    # Check if Docker daemon is running
                    if docker info >/dev/null 2>&1; then
                        echo -e "${GREEN}✅ Docker is ready!${RESET}"
                        return 0
                    else
                        echo -e "${YELLOW}⚠️  Docker Desktop found but not running${RESET}"
                        echo -e "${CYAN}🚀 Starting Docker Desktop automatically...${RESET}"
                        
                        # Try to start Docker Desktop automatically
                        local docker_desktop_exe="/c/Program Files/Docker/Docker/Docker Desktop.exe"
                        if [ -f "$docker_desktop_exe" ]; then
                            echo -e "${CYAN}📋 Starting Docker Desktop from: $docker_desktop_exe${RESET}"
                            "$docker_desktop_exe" &
                        else
                            # Try alternative path
                            docker_desktop_exe="/c/Program Files (x86)/Docker/Docker/Docker Desktop.exe"
                            if [ -f "$docker_desktop_exe" ]; then
                                echo -e "${CYAN}📋 Starting Docker Desktop from: $docker_desktop_exe${RESET}"
                                "$docker_desktop_exe" &
                            else
                                # Try PowerShell method
                                echo -e "${CYAN}📋 Starting Docker Desktop via PowerShell...${RESET}"
                                powershell.exe -Command "Start-Process 'Docker Desktop'" 2>/dev/null &
                            fi
                        fi
                        
                        echo -e "${YELLOW}⏳ Waiting for Docker Desktop to start (this may take 1-3 minutes)...${RESET}"
                        
                        # Wait for Docker to be ready
                        local attempts=0
                        local max_attempts=30  # 5 minutes total
                        
                        while [ $attempts -lt $max_attempts ]; do
                            if docker info >/dev/null 2>&1; then
                                echo -e "${GREEN}✅ Docker Desktop started successfully!${RESET}"
                                return 0
                            fi
                            
                            # Show progress every 30 seconds
                            if [ $((attempts % 3)) -eq 0 ] && [ $attempts -gt 0 ]; then
                                local elapsed=$((attempts * 10))
                                echo -e "${CYAN}   Still starting Docker... (${elapsed}s elapsed)${RESET}"
                            fi
                            
                            sleep 10
                            attempts=$((attempts + 1))
                        done
                        
                        echo -e "${RED}❌ Docker Desktop failed to start within 5 minutes${RESET}"
                        echo -e "${CYAN}📋 Please try:${RESET}"
                        echo -e "${CYAN}   1. Start Docker Desktop manually${RESET}"
                        echo -e "${CYAN}   2. Wait for it to fully load${RESET}"
                        echo -e "${CYAN}   3. Run this script again${RESET}"
                        exit 1
                    fi
                fi
            done
        fi
        
        echo -e "${YELLOW}Docker not found.${RESET}"
        
        # Detect operating system
        if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ -n "$WINDIR" ]]; then
            # Windows environment (Git Bash, MSYS2, Cygwin)
            echo -e "${YELLOW}Installing Docker Desktop on Windows...${RESET}"
            
            # Create temp directory for download (Windows compatible)
            TEMP_DIR="$HOME/docker_install_temp"
            mkdir -p "$TEMP_DIR"
            
            echo -e "${CYAN}📥 Downloading Docker Desktop installer...${RESET}"
            INSTALLER_PATH="$TEMP_DIR/DockerDesktopInstaller.exe"
            
            if curl -L -o "$INSTALLER_PATH" "https://desktop.docker.com/win/stable/Docker%20Desktop%20Installer.exe"; then
                echo -e "${GREEN}✅ Download completed${RESET}"
                
                echo -e "${CYAN}🚀 Starting Docker Desktop installation...${RESET}"
                echo -e "${YELLOW}⚠️  You may need to approve the installation in Windows${RESET}"
                
                # Convert to Windows path and run installer
                WINDOWS_INSTALLER_PATH=$(cygpath -w "$INSTALLER_PATH" 2>/dev/null || echo "$INSTALLER_PATH")
                echo -e "${CYAN}📋 Running installer: $WINDOWS_INSTALLER_PATH${RESET}"
                
                # Try different installation methods (non-blocking)
                echo -e "${CYAN}📋 Starting Docker Desktop installation in background...${RESET}"
                
                # Method 1: Try PowerShell with Start-Process (non-blocking)
                if powershell.exe -Command "Start-Process -FilePath '$WINDOWS_INSTALLER_PATH' -ArgumentList 'install','--quiet','--accept-license'" 2>/dev/null; then
                    echo -e "${GREEN}✅ Installation started via PowerShell${RESET}"
                # Method 2: Try cmd with start command (non-blocking)
                elif cmd.exe /c "start \"Docker Install\" \"$WINDOWS_INSTALLER_PATH\" install --quiet --accept-license" 2>/dev/null; then
                    echo -e "${GREEN}✅ Installation started via CMD${RESET}"
                # Method 3: Direct execution in background
                else
                    echo -e "${YELLOW}⚠️  Using fallback installation method${RESET}"
                    "$INSTALLER_PATH" install --quiet --accept-license </dev/null &>/dev/null &
                    echo -e "${GREEN}✅ Installation started in background${RESET}"
                fi
                
                echo -e "${CYAN}⏳ Waiting for Docker Desktop to install and start...${RESET}"
                echo -e "${YELLOW}💡 This may take 3-10 minutes depending on your system${RESET}"
                
                # Check if Docker is now available
                local attempts=0
                local max_attempts=60  # 10 minutes total
                
                while [ $attempts -lt $max_attempts ]; do
                    # Check if docker command exists
                    if command -v docker >/dev/null 2>&1; then
                        echo -e "${GREEN}📦 Docker command found!${RESET}"
                        
                        # Check if Docker daemon is running
                        if docker info >/dev/null 2>&1; then
                            echo -e "${GREEN}✅ Docker Desktop installed and running successfully!${RESET}"
                            rm -rf "$TEMP_DIR"
                            return 0
                        else
                            echo -e "${CYAN}🔄 Docker found but daemon not ready yet...${RESET}"
                        fi
                    else
                        # Show progress every 30 seconds
                        if [ $((attempts % 3)) -eq 0 ] && [ $attempts -gt 0 ]; then
                            local elapsed=$((attempts * 10))
                            echo -e "${CYAN}   Still installing... (${elapsed}s elapsed, checking every 10s)${RESET}"
                        fi
                    fi
                    
                    sleep 10
                    attempts=$((attempts + 1))
                done
                
                echo -e "${YELLOW}⚠️  Docker Desktop installed but may need manual start${RESET}"
                echo -e "${CYAN}📋 Please:${RESET}"
                echo -e "${CYAN}   1. Check if Docker Desktop started automatically${RESET}"
                echo -e "${CYAN}   2. If not, start it manually from Start Menu${RESET}"
                echo -e "${CYAN}   3. Wait for it to fully load, then restart this script${RESET}"
                rm -rf "$TEMP_DIR"
                exit 1
            else
                echo -e "${RED}❌ Failed to download Docker Desktop installer${RESET}"
                echo -e "${CYAN}📋 Please manually:${RESET}"
                echo -e "${CYAN}   1. Download from: https://desktop.docker.com/win/stable/Docker%20Desktop%20Installer.exe${RESET}"
                echo -e "${CYAN}   2. Install and start Docker Desktop${RESET}"
                echo -e "${CYAN}   3. Restart this script${RESET}"
                exit 1
            fi
        else
            # Linux environment (Ubuntu/Debian)
            echo -e "${YELLOW}Installing Docker on Linux...${RESET}"
        sudo apt update
        sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
        sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
        sudo apt update
        sudo apt install -y docker-ce
        sudo systemctl enable docker
        sudo systemctl start docker
        # Add current user to docker group
        sudo usermod -aG docker $USER
        echo -e "${YELLOW}Please log out and log back in for Docker permissions to take effect.${RESET}"
        fi
    else
        # Docker is found, check if it's running
        if ! docker info >/dev/null 2>&1; then
            echo -e "${YELLOW}⚠️  Docker is installed but not running.${RESET}"
            
            if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ -n "$WINDIR" ]]; then
                # Windows
                echo -e "${CYAN}📋 Please start Docker Desktop and try again.${RESET}"
                exit 1
            else
                # Linux
                echo -e "${CYAN}Starting Docker service...${RESET}"
                sudo systemctl start docker
            fi
        fi
    fi
}

# === Check Cron ===
function check_cron() {
    # Detect operating system for cron handling
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ -n "$WINDIR" ]]; then
        # Windows environment - cron not needed, use Windows Task Scheduler instead
        echo -e "${CYAN}📋 Windows detected - using Windows Task Scheduler for cleanup tasks${RESET}"
        return 0
    else
        # Linux environment - check and install cron
        if ! command -v cron >/dev/null 2>&1; then
            echo -e "${YELLOW}Cron is not available. Installing cron...${RESET}"
            sudo apt update
            sudo apt install -y cron
            sudo systemctl enable cron
            sudo systemctl start cron
        fi
    fi
}

# === Build Docker Image for Existing Node ===
function build_image_existing_node() {
    WORKDIR=$(mktemp -d)
    cd "$WORKDIR"

    cat > Dockerfile <<EOF
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/root/.nexus/bin:\$PATH"

RUN apt-get update && apt-get install -y \\
    curl \\
    screen \\
    bash \\
    && rm -rf /var/lib/apt/lists/*

# Install Nexus CLI and update PATH
RUN curl https://cli.nexus.xyz/ | sh \\
    && echo 'export PATH="/root/.nexus/bin:\$PATH"' >> /root/.bashrc \\
    && ln -sf /root/.nexus/bin/nexus-cli /usr/local/bin/nexus-cli

COPY entrypoint-existing.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
EOF

    cat > entrypoint-existing.sh <<EOF
#!/bin/bash
set -e

# Source bashrc to get PATH
source /root/.bashrc

echo "🚀 Starting Nexus Node with Existing ID..."

# Check if wallet address and node ID are provided
if [ -z "\$WALLET_ADDRESS" ]; then
    echo "❌ WALLET_ADDRESS is not set"
    exit 1
fi

if [ -z "\$EXISTING_NODE_ID" ]; then
    echo "❌ EXISTING_NODE_ID is not set"
    exit 1
fi

echo "📝 Using existing Node ID: \$EXISTING_NODE_ID"
echo "💼 Using wallet address: \$WALLET_ADDRESS"

# Kill any existing screen sessions
screen -S nexus -X quit >/dev/null 2>&1 || true

# Start the node with existing ID
echo "🎯 Starting Nexus node with existing ID: \$EXISTING_NODE_ID"
echo "⏳ Initializing node (this may take 15-30 seconds)..."
screen -dmS nexus bash -c "nexus-cli start --node-id \$EXISTING_NODE_ID 2>&1 | tee -a /root/nexus.log"

# Wait for node to start
echo "📋 Waiting for node initialization..."
sleep 8

# Check if screen session is running
if screen -list | grep -q "nexus"; then
    echo "✅ Node is running in the background"
    echo "📊 Node ID: \$EXISTING_NODE_ID"
    echo "💼 Wallet: \$WALLET_ADDRESS"
else
    echo "❌ Failed to start the node"
    cat /root/nexus.log
    exit 1
fi

# Follow the logs
tail -f /root/nexus.log
EOF

    docker build -t "$IMAGE_NAME" .
    cd - > /dev/null
    rm -rf "$WORKDIR"
}

# === Build Docker Image ===
function build_image() {
    WORKDIR=$(mktemp -d)
    cd "$WORKDIR"

    cat > Dockerfile <<EOF
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/root/.nexus/bin:\$PATH"

RUN apt-get update && apt-get install -y \\
    curl \\
    screen \\
    bash \\
    && rm -rf /var/lib/apt/lists/*

# Install Nexus CLI and update PATH
RUN curl https://cli.nexus.xyz/ | sh \\
    && echo 'export PATH="/root/.nexus/bin:\$PATH"' >> /root/.bashrc \\
    && ln -sf /root/.nexus/bin/nexus-cli /usr/local/bin/nexus-cli

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
EOF

    cat > entrypoint.sh <<EOF
#!/bin/bash
set -e

# Source bashrc to get PATH
source /root/.bashrc

echo "🚀 Starting Nexus Node Setup..."

# Check if wallet address is provided
if [ -z "\$WALLET_ADDRESS" ]; then
    echo "❌ WALLET_ADDRESS is not set"
    exit 1
fi

echo "📝 Registering user with wallet address: \$WALLET_ADDRESS"
echo "⏳ This may take 10-30 seconds depending on network..."

# Register user with wallet address with timeout
timeout 45 nexus-cli register-user --wallet-address "\$WALLET_ADDRESS" 2>&1 | tee /root/registration.log
USER_REG_EXIT_CODE=\${PIPESTATUS[0]}

if [ \$USER_REG_EXIT_CODE -eq 124 ]; then
    echo "❌ User registration timed out after 45 seconds"
    echo "This might be due to network issues or server load."
    echo "Please try again later or check your internet connection."
    exit 1
elif [ \$USER_REG_EXIT_CODE -ne 0 ]; then
    echo "❌ User registration failed with exit code: \$USER_REG_EXIT_CODE"
    cat /root/registration.log
    exit 1
fi

echo "🔗 Registering new node..."
echo "⏳ Contacting Nexus servers..."

# Register node with timeout and better error handling
timeout 60 nexus-cli register-node 2>&1 | tee /root/node-registration.log
NODE_REG_EXIT_CODE=\${PIPESTATUS[0]}

if [ \$NODE_REG_EXIT_CODE -eq 124 ]; then
    echo "❌ Node registration timed out after 60 seconds"
    echo "This might be due to network issues or server load."
    echo "Please try again later or check your internet connection."
    exit 1
elif [ \$NODE_REG_EXIT_CODE -ne 0 ]; then
    echo "❌ Node registration failed with exit code: \$NODE_REG_EXIT_CODE"
    cat /root/node-registration.log
    exit 1
fi

# Read the registration output
NODE_REGISTRATION_OUTPUT=\$(cat /root/node-registration.log)

# Extract Node ID from registration output
NODE_ID=\$(echo "\$NODE_REGISTRATION_OUTPUT" | grep -o "node with ID: [0-9]*" | grep -o "[0-9]*" | head -1)

if [ -z "\$NODE_ID" ]; then
    echo "❌ Failed to extract Node ID from registration"
    echo "Registration output:"
    cat /root/node-registration.log
    exit 1
fi

echo "✅ Node registered successfully with ID: \$NODE_ID"

# Kill any existing screen sessions
screen -S nexus -X quit >/dev/null 2>&1 || true

# Start the node with proper logging
echo "🎯 Starting Nexus node with ID: \$NODE_ID"
echo "⏳ Initializing node (this may take 15-30 seconds)..."
screen -dmS nexus bash -c "nexus-cli start 2>&1 | tee -a /root/nexus.log"

# Wait for node to start
echo "📋 Waiting for node initialization..."
sleep 8

# Check if screen session is running
if screen -list | grep -q "nexus"; then
    echo "✅ Node is running in the background"
    echo "📊 Node ID: \$NODE_ID"
    echo "💼 Wallet: \$WALLET_ADDRESS"
else
    echo "❌ Failed to start the node"
    cat /root/nexus.log
    exit 1
fi

# Follow the logs
tail -f /root/nexus.log
EOF

    docker build -t "$IMAGE_NAME" .
    cd - > /dev/null
    rm -rf "$WORKDIR"
}

# === Run Container with Existing Node ID ===
function run_container_existing_node() {
    local wallet_address=$1
    local existing_node_id=$2
    local timestamp=$(date +%s)
    local container_name="${BASE_CONTAINER_NAME}-${timestamp}"
    local log_file="${LOG_DIR}/nexus-${timestamp}.log"

    # Create log directory with proper permissions
    mkdir -p "$LOG_DIR"
    chmod 755 "$LOG_DIR"
    
    # Remove existing container if it exists
    docker rm -f "$container_name" 2>/dev/null || true
    
    # Create log file with proper permissions
    touch "$log_file"
    chmod 644 "$log_file"

    echo -e "${CYAN}🚀 Starting Nexus node with existing Node ID: $existing_node_id${RESET}"
    echo -e "${CYAN}💼 Wallet: $wallet_address${RESET}"
    echo -e "${CYAN}📋 Container name: $container_name${RESET}"

    # Run container with wallet address and existing node ID
    docker run -d --name "$container_name" \
        -v "$log_file":/root/nexus.log \
        -e WALLET_ADDRESS="$wallet_address" \
        -e EXISTING_NODE_ID="$existing_node_id" \
        "$IMAGE_NAME"

    # Wait for initial setup
    echo -e "${YELLOW}⏳ Setting up node with existing ID (this may take 30-60 seconds)...${RESET}"
    echo -e "${CYAN}📋 Progress: Container started, initializing with Node ID $existing_node_id...${RESET}"
    
    # Set up log cleanup task (platform-specific)
    check_cron
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ -n "$WINDIR" ]]; then
        # Windows - create a simple cleanup script (no cron needed)
        echo -e "${CYAN}📋 Log cleanup will be handled manually on Windows${RESET}"
    else
        # Linux - use cron
        echo "0 0 * * * rm -f $log_file" | sudo tee "/etc/cron.d/nexus-log-cleanup-${timestamp}" > /dev/null
        sudo chmod 644 "/etc/cron.d/nexus-log-cleanup-${timestamp}"
    fi
    
    # Wait and check if container is running
    sleep 15
    if docker inspect -f '{{.State.Status}}' "$container_name" 2>/dev/null | grep -q "running"; then
        echo -e "${GREEN}✅ Node started successfully with existing ID!${RESET}"
        echo -e "${GREEN}📊 Node ID: $existing_node_id${RESET}"
        echo -e "${CYAN}💼 Wallet: $wallet_address${RESET}"
        echo -e "${CYAN}📁 Log file: $log_file${RESET}"
        
        # Log the successful startup
        log_node_clean "$log_file" "Node $existing_node_id started successfully with wallet $wallet_address"
        # Don't trim immediately - let logs accumulate first
    else
        echo -e "${RED}❌ Node failed to start${RESET}"
        echo -e "${YELLOW}📋 Container logs (last 30 lines):${RESET}"
        docker logs "$container_name" 2>&1 | tail -30
        
        # Check if container exited and why
        local exit_code=$(docker inspect -f '{{.State.ExitCode}}' "$container_name" 2>/dev/null)
        if [ -n "$exit_code" ] && [ "$exit_code" != "0" ]; then
            echo -e "${RED}🚫 Container exited with code: $exit_code${RESET}"
        fi
        
        echo -e "${CYAN}💡 Common issues:${RESET}"
        echo -e "${CYAN}   • Invalid Node ID - check if the Node ID exists${RESET}"
        echo -e "${CYAN}   • Node ID already in use by another instance${RESET}"
        echo -e "${CYAN}   • Network connectivity problems${RESET}"
        echo -e "${CYAN}   • Try with a different Node ID${RESET}"
        
        return 1
    fi
}

# === Run Container ===
function run_container() {
    local wallet_address=$1
    local timestamp=$(date +%s)
    local container_name="${BASE_CONTAINER_NAME}-${timestamp}"
    local log_file="${LOG_DIR}/nexus-${timestamp}.log"

    # Create log directory with proper permissions
    mkdir -p "$LOG_DIR"
    chmod 755 "$LOG_DIR"
    
    # Remove existing container if it exists
    docker rm -f "$container_name" 2>/dev/null || true
    
    # Create log file with proper permissions
    touch "$log_file"
    chmod 644 "$log_file"

    echo -e "${CYAN}🚀 Starting new Nexus node with wallet: $wallet_address${RESET}"
    echo -e "${CYAN}📋 Container name: $container_name${RESET}"

    # Run container with wallet address
    docker run -d --name "$container_name" \
        -v "$log_file":/root/nexus.log \
        -e WALLET_ADDRESS="$wallet_address" \
        "$IMAGE_NAME"

    # Wait for initial setup and get the node ID from logs
    echo -e "${YELLOW}⏳ Setting up node (this may take 30-60 seconds)...${RESET}"
    echo -e "${CYAN}📋 Progress: Container started, waiting for registration...${RESET}"
    
    # More efficient polling with progress updates
    local node_id=""
    local attempts=0
    local max_attempts=45  # Increased to 90 seconds total
    
    while [ $attempts -lt $max_attempts ] && [ -z "$node_id" ]; do
        # Check container status first
        if ! docker inspect -f '{{.State.Status}}' "$container_name" 2>/dev/null | grep -q "running"; then
            echo -e "${RED}❌ Container stopped unexpectedly${RESET}"
            
            # Get container exit code and logs for debugging
            local exit_code=$(docker inspect -f '{{.State.ExitCode}}' "$container_name" 2>/dev/null)
            echo -e "${RED}🚫 Container exit code: $exit_code${RESET}"
            echo -e "${YELLOW}📋 Container logs:${RESET}"
            docker logs "$container_name" 2>&1 | tail -20 | sed 's/^/   /'
            
            # Show common exit code meanings
            case $exit_code in
                1) echo -e "${CYAN}💡 Exit code 1: General application error${RESET}" ;;
                125) echo -e "${CYAN}💡 Exit code 125: Docker daemon error${RESET}" ;;
                126) echo -e "${CYAN}💡 Exit code 126: Container command not executable${RESET}" ;;
                127) echo -e "${CYAN}💡 Exit code 127: Container command not found${RESET}" ;;
                *) echo -e "${CYAN}💡 Check container logs above for error details${RESET}" ;;
            esac
            
            break
        fi
        
        # Try to extract Node ID
        node_id=$(docker logs "$container_name" 2>&1 | grep -o "node with ID: [0-9]*" | grep -o "[0-9]*" | head -1)
        
        if [ -z "$node_id" ]; then
            # Show progress every 10 seconds
            if [ $((attempts % 5)) -eq 0 ] && [ $attempts -gt 0 ]; then
                local elapsed=$((attempts * 2))
                echo -e "${CYAN}📋 Still setting up... (${elapsed}s elapsed)${RESET}"
                
                # Show last few log lines for debugging
                local last_log=$(docker logs "$container_name" 2>&1 | tail -1)
                if [ -n "$last_log" ]; then
                    echo -e "${YELLOW}   Latest: $last_log${RESET}"
                fi
            fi
            sleep 2
            attempts=$((attempts + 1))
        fi
    done

    # Set up log cleanup task (platform-specific)
    check_cron
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ -n "$WINDIR" ]]; then
        # Windows - create a simple cleanup script (no cron needed)
        echo -e "${CYAN}📋 Log cleanup will be handled manually on Windows${RESET}"
    else
        # Linux - use cron
        echo "0 0 * * * rm -f $log_file" | sudo tee "/etc/cron.d/nexus-log-cleanup-${timestamp}" > /dev/null
        sudo chmod 644 "/etc/cron.d/nexus-log-cleanup-${timestamp}"
    fi
    
    # Check if container is still running
    if docker inspect -f '{{.State.Status}}' "$container_name" 2>/dev/null | grep -q "running"; then
        echo -e "${GREEN}✅ Node started successfully!${RESET}"
        if [ -n "$node_id" ]; then
            echo -e "${GREEN}📊 Node ID: $node_id${RESET}"
            log_node_clean "$log_file" "Node $node_id started successfully with wallet $wallet_address"
            # Don't trim immediately - let logs accumulate first
        else
            echo -e "${YELLOW}⚠️  Node is running but ID not yet detected${RESET}"
            log_node_clean "$log_file" "Node started successfully with wallet $wallet_address"
        fi
        echo -e "${CYAN}💼 Wallet: $wallet_address${RESET}"
        echo -e "${CYAN}📁 Log file: $log_file${RESET}"
    else
        echo -e "${RED}❌ Node failed to start${RESET}"
        echo -e "${YELLOW}📋 Container logs (last 30 lines):${RESET}"
        docker logs "$container_name" 2>&1 | tail -30
        
        # Check if container exited and why
        local exit_code=$(docker inspect -f '{{.State.ExitCode}}' "$container_name" 2>/dev/null)
        if [ -n "$exit_code" ] && [ "$exit_code" != "0" ]; then
            echo -e "${RED}🚫 Container exited with code: $exit_code${RESET}"
        fi
        
        echo -e "${CYAN}💡 Common issues:${RESET}"
        echo -e "${CYAN}   • Network connectivity problems${RESET}"
        echo -e "${CYAN}   • Nexus servers temporarily overloaded${RESET}"
        echo -e "${CYAN}   • Firewall blocking outbound connections${RESET}"
        echo -e "${CYAN}   • Try running the script again in a few minutes${RESET}"
        
        return 1
    fi
}

# === Uninstall Node by Timestamp ===
function uninstall_node_by_timestamp() {
    local timestamp=$1
    local cname="${BASE_CONTAINER_NAME}-${timestamp}"
    local log_file="${LOG_DIR}/nexus-${timestamp}.log"
    
    # Get node info before removal
    local node_info=$(get_node_info "$cname")
    local node_id=${node_info%%\|*}
    
    # Log clean removal message before removing log file
    if [ -f "$log_file" ]; then
        log_node_clean "$log_file" "Container $timestamp (Node ID: $node_id) is being removed"
    fi
    
    docker rm -f "$cname" 2>/dev/null || true
    rm -f "$log_file"
    sudo rm -f "/etc/cron.d/nexus-log-cleanup-${timestamp}"
    echo -e "${YELLOW}Container $timestamp (Node ID: $node_id) has been removed.${RESET}"
}

# === Uninstall Node (Legacy - kept for compatibility) ===
function uninstall_node() {
    local node_id=$1
    local cname="${BASE_CONTAINER_NAME}-${node_id}"
    local log_file="${LOG_DIR}/nexus-${node_id}.log"
    
    # Log clean removal message before removing log file
    if [ -f "$log_file" ]; then
        log_node_clean "$log_file" "Node $node_id is being removed"
    fi
    
    docker rm -f "$cname" 2>/dev/null || true
    rm -f "$log_file"
    sudo rm -f "/etc/cron.d/nexus-log-cleanup-${node_id}"
    echo -e "${YELLOW}Node $node_id has been removed.${RESET}"
}

# === Get All Nodes ===
function get_all_nodes() {
    # Ensure Docker is available
    if ! ensure_docker_available; then
        return 1
    fi
    
    # Get container names without complex piping
    local containers=()
    while IFS= read -r container_name; do
        if [[ "$container_name" =~ ^${BASE_CONTAINER_NAME}- ]]; then
            # Extract timestamp from container name
            local timestamp="${container_name#${BASE_CONTAINER_NAME}-}"
            containers+=("$timestamp")
        fi
    done < <(docker ps -a --format "{{.Names}}" 2>/dev/null)
    
    # Output the timestamps
    for container in "${containers[@]}"; do
        echo "$container"
    done
}

# === Get Node Info ===
function get_node_info() {
    local container_name="$1"
    local node_id="Unknown"
    local wallet_address="Unknown"
    
    # Ensure Docker is available
    if ! ensure_docker_available; then
        echo "Unknown|Unknown"
        return 1
    fi
    
    # Try to get node ID from container logs (simplified)
    local logs_output
    logs_output=$(docker logs "$container_name" 2>/dev/null || echo "")
    if [[ "$logs_output" =~ node\ with\ ID:\ ([0-9]+) ]]; then
        node_id="${BASH_REMATCH[1]}"
    fi
    
    # Try to get wallet address from container environment (simplified)
    local env_output
    env_output=$(docker inspect "$container_name" --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null || echo "")
    while IFS= read -r env_line; do
        if [[ "$env_line" =~ ^WALLET_ADDRESS=(.+)$ ]]; then
            wallet_address="${BASH_REMATCH[1]}"
            break
        fi
    done <<< "$env_output"
    
    echo "${node_id}|${wallet_address}"
}

# === List All Nodes ===
function list_nodes() {
    show_header
    echo -e "${CYAN}📊 Registered Nodes:${RESET}"
    echo "-----------------------------------------------------------------------------------------"
    printf "%-3s %-12s %-12s %-8s %-8s\n" "No" "Container" "Status" "CPU" "Memory"
    echo "-----------------------------------------------------------------------------------------"
    local all_nodes=($(get_all_nodes))
    local failed_nodes=()
    for i in "${!all_nodes[@]}"; do
        local timestamp=${all_nodes[$i]}
        local container="${BASE_CONTAINER_NAME}-${timestamp}"
        local cpu="N/A"
        local mem="N/A"
        local status="Inactive"
        
        # Skip slow node info lookup for fast display
        
        if docker inspect "$container" &>/dev/null; then
            status=$(docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null)
            if [[ "$status" == "running" ]]; then
                # Get stats without using pipe characters in format
                local cpu_stats=$(docker stats --no-stream --format "{{.CPUPerc}}" "$container" 2>/dev/null)
                local mem_stats=$(docker stats --no-stream --format "{{.MemUsage}}" "$container" 2>/dev/null)
                cpu="$cpu_stats"
                mem="${mem_stats%%/*}"  # Get everything before first /
            elif [[ "$status" == "exited" ]]; then
                failed_nodes+=("$timestamp")
            fi
        fi
        
        printf "%-3s %-12s %-12s %-8s %-8s\n" "$((i+1))" "$timestamp" "$status" "$cpu" "$mem"
    done
    echo "-----------------------------------------------------------------------------------------"
    if [ ${#failed_nodes[@]} -gt 0 ]; then
        echo -e "${RED}⚠️ Failed to start node(s) (exited):${RESET}"
        for id in "${failed_nodes[@]}"; do
            echo "- Container: $id"
        done
    fi
    read -p "Press enter to return to menu..."
}

# === Trim Log File to Last 2 Lines ===
function trim_log_file() {
    local log_file="$1"
    
    if [ -f "$log_file" ]; then
        # Get the last 2 lines and overwrite the file
        local temp_file="${log_file}.tmp"
        tail -n 2 "$log_file" > "$temp_file" 2>/dev/null
        mv "$temp_file" "$log_file" 2>/dev/null || rm -f "$temp_file"
    fi
}

# === Auto-Trim All Log Files ===
function auto_trim_all_logs() {
    if [ -d "$LOG_DIR" ]; then
        for log_file in "$LOG_DIR"/nexus-*.log; do
            if [ -f "$log_file" ]; then
                trim_log_file "$log_file"
            fi
        done
        
        # Also trim auto-restart log
        if [ -f "${LOG_DIR}/auto-restart.log" ]; then
            trim_log_file "${LOG_DIR}/auto-restart.log"
        fi
    fi
}

# === View Node Logs ===
function view_logs() {
    local all_nodes=($(get_all_nodes))
    if [ ${#all_nodes[@]} -eq 0 ]; then
        echo "No nodes found."
        read -p "Press enter..."
        return
    fi
    echo "Select a node to view logs:"
    for i in "${!all_nodes[@]}"; do
        local timestamp=${all_nodes[$i]}
        # Fast display - skip Docker API calls for listing
        echo "$((i+1)). Container: $timestamp"
    done
    read -rp "Number: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice > 0 && choice <= ${#all_nodes[@]} )); then
        local selected=${all_nodes[$((choice-1))]}
        local log_file="${LOG_DIR}/nexus-${selected}.log"
        local container="${BASE_CONTAINER_NAME}-${selected}"
        local node_info=$(get_node_info "$container")
        local node_id=${node_info%%\|*}
        
        echo -e "${YELLOW}Logs for container: $selected (Node ID: $node_id)${RESET}"
        echo "--------------------------------------------------------------"
        if [ -f "$log_file" ]; then
            # Check if log file has content
            if [ -s "$log_file" ]; then
                echo -e "${CYAN}📁 Log file size: $(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null || echo "unknown") bytes${RESET}"
                echo -e "${CYAN}📋 Last 10 lines:${RESET}"
                tail -n 10 "$log_file" 2>/dev/null | sed 's/^/  /' || echo "  Error reading log file"
            else
                echo "  Log file exists but is empty"
                echo -e "${CYAN}💡 This might mean:${RESET}"
                echo -e "${CYAN}   • Node is still starting up${RESET}"
                echo -e "${CYAN}   • Logs are being written to container instead of file${RESET}"
                echo -e "${CYAN}   • Check container logs with: docker logs $container${RESET}"
            fi
        else
            echo "  No log file found at: $log_file"
        fi
        echo "--------------------------------------------------------------"
    fi
    read -p "Press enter..."
}

# === Uninstall Multiple Nodes ===
function batch_uninstall_nodes() {
    local all_nodes=($(get_all_nodes))
    if [ ${#all_nodes[@]} -eq 0 ]; then
        echo "No nodes found."
        read -p "Press enter..."
        return
    fi
    echo "Enter the numbers of the nodes to uninstall (separated by space):"
    for i in "${!all_nodes[@]}"; do
        local timestamp=${all_nodes[$i]}
        # Fast display - skip Docker API calls for listing
        echo "$((i+1)). Container: $timestamp"
    done
    read -rp "Numbers: " input
    for num in $input; do
        if [[ "$num" =~ ^[0-9]+$ ]] && (( num > 0 && num <= ${#all_nodes[@]} )); then
            uninstall_node_by_timestamp "${all_nodes[$((num-1))]}"
        else
            echo "Skipped: $num"
        fi
    done
    read -p "Press enter..."
}

# === Uninstall All Nodes ===
function uninstall_all_nodes() {
    local all_nodes=($(get_all_nodes))
    if [ ${#all_nodes[@]} -eq 0 ]; then
        echo "No nodes found."
        read -p "Press enter..."
        return
    fi
    echo "Are you sure you want to remove ALL nodes? (y/n)"
    read -rp "Confirm: " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        for timestamp in "${all_nodes[@]}"; do
            uninstall_node_by_timestamp "$timestamp"
        done
        echo "All nodes have been removed."
    else
        echo "Cancelled."
    fi
    read -p "Press enter..."
}

# === Restart All Nodes ===
function restart_all_nodes() {
    local all_nodes=($(get_all_nodes))
    if [ ${#all_nodes[@]} -eq 0 ]; then
        echo "No nodes found."
        read -p "Press enter..."
        return
    fi
    
    echo "Are you sure you want to restart ALL nodes? (y/n)"
    read -rp "Confirm: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        read -p "Press enter..."
        return
    fi
    
    echo -e "${YELLOW}🔄 Restarting all nodes...${RESET}"
    
    for timestamp in "${all_nodes[@]}"; do
        local container="${BASE_CONTAINER_NAME}-${timestamp}"
        local log_file="${LOG_DIR}/nexus-${timestamp}.log"
        local node_info=$(get_node_info "$container")
        local node_id=${node_info%%\|*}
        
        echo -e "${CYAN}Restarting container: $timestamp (Node ID: $node_id)${RESET}"
        
        # Log clean restart message
        log_node_clean "$log_file" "Manual restart initiated for container: $timestamp (Node ID: $node_id)"
        
        # Stop the container gracefully
        docker stop "$container" 2>/dev/null || true
        sleep 2
        
        # Start the container again
        docker start "$container" 2>/dev/null || {
            echo -e "${RED}Failed to restart container $timestamp${RESET}"
            log_node_clean "$log_file" "Failed to restart container $timestamp"
            continue
        }
        
        # Wait a moment and check if it's running
        sleep 3
        if docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null | grep -q "running"; then
            echo -e "${GREEN}✅ Container $timestamp restarted successfully${RESET}"
            log_node_clean "$log_file" "Container $timestamp restarted successfully"
        else
            echo -e "${RED}❌ Container $timestamp failed to start${RESET}"
            log_node_clean "$log_file" "Container $timestamp failed to start after restart"
        fi
    done
    
    echo -e "${GREEN}🎉 All nodes restart completed!${RESET}"
    read -p "Press enter..."
}

# === Clear All Logs ===
function clear_all_logs() {
    echo -e "${YELLOW}⚠️  This will delete ALL log files including:${RESET}"
    echo -e "${CYAN}   • All individual node logs (nexus-*.log)${RESET}"
    echo -e "${CYAN}   • Auto-restart log (auto-restart.log)${RESET}"
    echo -e "${CYAN}   • Log directory: $LOG_DIR${RESET}"
    echo ""
    
    # Show current log files if any exist
    if [ -d "$LOG_DIR" ] && [ "$(ls -A "$LOG_DIR" 2>/dev/null)" ]; then
        echo -e "${CYAN}📁 Current log files:${RESET}"
        # List log files without using pipe characters
        if [ -d "$LOG_DIR" ]; then
            local found_logs=false
            for log_file in "$LOG_DIR"/*.log; do
                if [ -f "$log_file" ]; then
                    local filename=$(basename "$log_file")
                    local filesize=$(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null || echo "unknown")
                    echo "   • $filename ($filesize bytes)"
                    found_logs=true
                fi
            done
            if [ "$found_logs" = false ]; then
                echo "   • No .log files found"
            fi
        else
            echo "   • No .log files found"
        fi
        echo ""
    else
        echo -e "${GREEN}📁 No log files found to delete.${RESET}"
        read -p "Press enter..."
        return
    fi
    
    echo -e "${RED}⚠️  WARNING: This action cannot be undone!${RESET}"
    echo "Are you sure you want to delete ALL logs? (y/n)"
    read -rp "Confirm: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        read -p "Press enter..."
        return
    fi
    
    echo -e "${YELLOW}🗑️  Clearing all logs...${RESET}"
    
    # Count files before deletion for reporting
    local deleted_count=0
    
    # Delete all log files in the log directory
    if [ -d "$LOG_DIR" ]; then
        # Count existing log files
        deleted_count=$(find "$LOG_DIR" -name "*.log" -type f 2>/dev/null | wc -l)
        
        # Delete individual node logs
        find "$LOG_DIR" -name "nexus-*.log" -type f -delete 2>/dev/null || true
        
        # Delete auto-restart log
        rm -f "${LOG_DIR}/auto-restart.log" 2>/dev/null || true
        
        # Remove empty log directory if it exists and is empty
        if [ -d "$LOG_DIR" ] && [ ! "$(ls -A "$LOG_DIR" 2>/dev/null)" ]; then
            rmdir "$LOG_DIR" 2>/dev/null || true
            echo -e "${GREEN}✅ Log directory removed (was empty)${RESET}"
        fi
    fi
    
    # Also clear any remaining log files that might be in use by containers
    echo -e "${CYAN}🔄 Checking for logs in use by containers...${RESET}"
    local all_nodes=($(get_all_nodes))
    for timestamp in "${all_nodes[@]}"; do
        local container="${BASE_CONTAINER_NAME}-${timestamp}"
        local log_file="${LOG_DIR}/nexus-${timestamp}.log"
        
        # If container is running, we need to recreate the log file
        if docker inspect "$container" &>/dev/null && docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null | grep -q "running"; then
            # Create empty log file for running container
            mkdir -p "$LOG_DIR"
            touch "$log_file"
            chmod 644 "$log_file"
            echo -e "${CYAN}   • Recreated log file for running container: $timestamp${RESET}"
        fi
    done
    
    echo -e "${GREEN}🎉 Log cleanup completed!${RESET}"
    if [ "$deleted_count" -gt 0 ]; then
        echo -e "${GREEN}✅ Deleted $deleted_count log files${RESET}"
    fi
    echo -e "${CYAN}📋 All logs have been cleared${RESET}"
    read -p "Press enter..."
}

# === Update All Nodes ===
function update_all_nodes() {
    local all_nodes=($(get_all_nodes))
    if [ ${#all_nodes[@]} -eq 0 ]; then
        echo "No nodes found."
        read -p "Press enter..."
        return
    fi
    
    echo -e "${YELLOW}⚠️  This will update all nodes to the latest Nexus CLI version.${RESET}"
    echo -e "${YELLOW}All nodes will be stopped, the Docker image will be rebuilt, and nodes will be restarted.${RESET}"
    echo "Are you sure you want to update ALL nodes? (y/n)"
    read -rp "Confirm: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        read -p "Press enter..."
        return
    fi
    
    echo -e "${YELLOW}🔄 Starting update process for all nodes...${RESET}"
    
    # Log the update start
    log_clean "Update process started for ${#all_nodes[@]} nodes"
    
    # Stop all running nodes first
    echo -e "${CYAN}Stopping all nodes...${RESET}"
    for timestamp in "${all_nodes[@]}"; do
        local container="${BASE_CONTAINER_NAME}-${timestamp}"
        local log_file="${LOG_DIR}/nexus-${timestamp}.log"
        local node_info=$(get_node_info "$container")
        local node_id=${node_info%%\|*}
        echo -e "${CYAN}Stopping container: $timestamp (Node ID: $node_id)${RESET}"
        log_node_clean "$log_file" "Container stopped for update process"
        docker stop "$container" 2>/dev/null || true
    done
    
    # Remove old Docker image and rebuild with latest Nexus CLI
    echo -e "${CYAN}🔨 Rebuilding Docker image with latest Nexus CLI...${RESET}"
    docker rmi "$IMAGE_NAME" 2>/dev/null || true
    build_image
    echo -e "${GREEN}✅ Docker image rebuilt successfully${RESET}"
    
    # Restart all nodes with the new image
    echo -e "${CYAN}🚀 Starting all nodes with updated image...${RESET}"
    for timestamp in "${all_nodes[@]}"; do
        local container="${BASE_CONTAINER_NAME}-${timestamp}"
        local log_file="${LOG_DIR}/nexus-${timestamp}.log"
        
        # Get wallet address from the old container before removing it
        # Get wallet address without using pipe characters
        local env_output=$(docker inspect "$container" --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null || echo "")
        local wallet_address="Unknown"
        while IFS= read -r env_line; do
            if [[ "$env_line" =~ ^WALLET_ADDRESS=(.+)$ ]]; then
                wallet_address="${BASH_REMATCH[1]}"
                break
            fi
        done <<< "$env_output"
        
        echo -e "${CYAN}Updating container: $timestamp${RESET}"
        
        # Remove old container and create new one
        docker rm -f "$container" 2>/dev/null || true
        
        # Log clean update message
        log_node_clean "$log_file" "Container updated to latest Nexus CLI version"
        
        # Run container with updated image and same wallet address
        docker run -d --name "$container" \
            -v "$log_file":/root/nexus.log \
            -e WALLET_ADDRESS="$wallet_address" \
            "$IMAGE_NAME"
        
        # Wait a moment and check if it's running
        sleep 5
        if docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null | grep -q "running"; then
            echo -e "${GREEN}✅ Container $timestamp updated and started successfully${RESET}"
            log_node_clean "$log_file" "Container $timestamp updated and started successfully"
        else
            echo -e "${RED}❌ Container $timestamp failed to start after update${RESET}"
            log_node_clean "$log_file" "Container $timestamp failed to start after update"
        fi
    done
    
    # Log the update completion
    log_clean "Update process completed for ${#all_nodes[@]} nodes"
    
    echo -e "${GREEN}🎉 All nodes update completed!${RESET}"
    echo -e "${CYAN}📋 All nodes have been updated to the latest Nexus CLI version${RESET}"
    read -p "Press enter..."
}

# === Setup Auto Restart Cron Job ===
function setup_auto_restart() {
    local script_path="$(realpath "$0")"
    local cron_job="0 0,2,4,6,8,10,12,14,16,18,20,22 * * * $script_path --auto-restart"
    
    # Remove existing auto-restart cron job
    sudo crontab -l 2>/dev/null | grep -v "nexus-node-fixed.sh --auto-restart" | sudo crontab - 2>/dev/null || true
    
    # Add new cron job
    (sudo crontab -l 2>/dev/null; echo "$cron_job") | sudo crontab - 2>/dev/null
    
    # Log clean setup message
    log_clean "Auto-restart cron job setup completed - scheduled every 2 hours"
    
    echo -e "${GREEN}✅ Auto-restart scheduled every 2 hours (12am, 2am, 4am, 6am, 8am, 10am, 12pm, 2pm, 4pm, 6pm, 8pm, 10pm)${RESET}"
    echo -e "${CYAN}📅 Cron job added successfully${RESET}"
}

# === Remove Auto Restart Cron Job ===
function remove_auto_restart() {
    sudo crontab -l 2>/dev/null | grep -v "nexus-node-fixed.sh --auto-restart" | sudo crontab - 2>/dev/null || true
    
    # Log clean removal message
    log_clean "Auto-restart cron job removed"
    
    echo -e "${YELLOW}Auto-restart cron job removed${RESET}"
}

# === Clean Log Functions ===
function log_clean() {
    echo "$(date): $1" >> "${LOG_DIR}/auto-restart.log"
}

function log_node_clean() {
    local log_file="$1"
    echo "$(date): $2" >> "$log_file"
}

# === Auto Restart Function (for cron) ===
function auto_restart_nodes() {
    local all_nodes=($(get_all_nodes))
    if [ ${#all_nodes[@]} -eq 0 ]; then
        log_clean "No nodes found for auto-restart"
        return
    fi
    
    log_clean "Starting auto-restart of ${#all_nodes[@]} nodes"
    
    for timestamp in "${all_nodes[@]}"; do
        local container="${BASE_CONTAINER_NAME}-${timestamp}"
        log_clean "Restarting container: $timestamp"
        
        # Stop the container gracefully
        docker stop "$container" 2>/dev/null || true
        sleep 2
        
        # Start the container again
        if docker start "$container" 2>/dev/null; then
            log_clean "Container $timestamp restarted successfully"
        else
            log_clean "Failed to restart container $timestamp"
        fi
        
        sleep 1
    done
    
    log_clean "Auto-restart completed"
}

# === Wallet Address Management ===
function save_wallet_address() {
    local wallet_address="$1"
    mkdir -p "$LOG_DIR"
    echo "$wallet_address" > "$WALLET_SAVE_FILE"
    chmod 600 "$WALLET_SAVE_FILE"  # Secure permissions
}

function get_saved_wallet_address() {
    if [ -f "$WALLET_SAVE_FILE" ]; then
        cat "$WALLET_SAVE_FILE" 2>/dev/null
    fi
}

function validate_wallet_address() {
    local wallet_address="$1"
    if [[ ! "$wallet_address" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
        return 1
    fi
    return 0
}

function get_wallet_address_interactive() {
    local saved_wallet=$(get_saved_wallet_address)
    local wallet_address=""
    
    if [ -n "$saved_wallet" ]; then
        echo -e "${CYAN}🔗 Wallet Address Options:${RESET}" >&2
        echo -e "${GREEN}1.${RESET} Use saved wallet: ${YELLOW}${saved_wallet}${RESET}" >&2
        echo -e "${GREEN}2.${RESET} Enter a different wallet address" >&2
        echo "" >&2
        read -rp "Choose option (1 or 2): " wallet_choice
        
        case $wallet_choice in
            1)
                wallet_address="$saved_wallet"
                echo -e "${GREEN}✅ Using saved wallet: $wallet_address${RESET}" >&2
                ;;
            2)
                echo -e "${CYAN}💡 Please enter your Nexus wallet address (0x...)${RESET}" >&2
                read -rp "Enter WALLET ADDRESS: " wallet_address
                ;;
            *)
                echo -e "${RED}❌ Invalid choice. Using saved wallet.${RESET}" >&2
                wallet_address="$saved_wallet"
                ;;
        esac
    else
        echo -e "${CYAN}🔗 Please provide your Nexus wallet address${RESET}" >&2
        echo -e "${YELLOW}💡 This should be your Ethereum wallet address (0x...)${RESET}" >&2
        read -rp "Enter WALLET ADDRESS: " wallet_address
    fi
    
    # Validate wallet address
    if [ -z "$wallet_address" ]; then
        echo -e "${RED}❌ Wallet address cannot be empty.${RESET}" >&2
        return 1
    fi
    
    if ! validate_wallet_address "$wallet_address"; then
        echo -e "${RED}❌ Invalid wallet address format. Please use format: 0x...${RESET}" >&2
        return 1
    fi
    
    # Save the wallet address for future use
    save_wallet_address "$wallet_address"
    echo "$wallet_address"  # This is the only output that gets captured
    return 0
}

# === Check if running as root ===
function check_root() {
    if [ "$EUID" -eq 0 ]; then
        echo -e "${RED}⚠️  Warning: Running as root is not recommended for security reasons.${RESET}"
        echo -e "${YELLOW}Consider running as a regular user with sudo privileges.${RESET}"
        read -p "Continue anyway? (y/n): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# === Handle Command Line Arguments ===
if [ "$1" = "--auto-restart" ]; then
    # Create log directory if it doesn't exist
    mkdir -p "$LOG_DIR"
    auto_restart_nodes
    exit 0
fi

# === MAIN MENU ===
check_root

while true; do
    show_header
    echo -e "${GREEN} 1.${RESET} ➤ Install & Run Node"
    echo -e "${GREEN} 2.${RESET} 📊 View All Node Status"
    echo -e "${GREEN} 3.${RESET} ❌ Remove Specific Node"
    echo -e "${GREEN} 4.${RESET} 🧾 View Node Logs"
    echo -e "${GREEN} 5.${RESET} 💥 Remove All Nodes"
    echo -e "${GREEN} 6.${RESET} 🔄 Restart All Nodes"
    echo -e "${GREEN} 7.${RESET} 🆙 Update All Nodes (Latest Nexus CLI)"
    echo -e "${GREEN} 8.${RESET} 🗑️  Clear All Logs"
    echo -e "${GREEN} 9.${RESET} ⏰ Setup Auto-Restart (Every 2 Hours)"
    echo -e "${GREEN}10.${RESET} 🚫 Remove Auto-Restart"
    echo -e "${GREEN} ${RESET} 🚪 ~CTRL + C for Exit~"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    read -rp "Choose an option (1–10): " choice
    case $choice in
        1)
            check_docker
            
            # Get wallet address interactively (with saved wallet option)
            WALLET_ADDRESS=$(get_wallet_address_interactive)
            if [ $? -ne 0 ] || [ -z "$WALLET_ADDRESS" ]; then
                echo -e "${RED}❌ Failed to get valid wallet address.${RESET}"
                read -p "Press enter..."
                continue
            fi
            
            # Ask if user wants to use existing Node ID or create new one
            echo -e "${CYAN}🔗 Node ID Options:${RESET}"
            echo -e "${GREEN}1.${RESET} Create a new Node ID (register new node)"
            echo -e "${GREEN}2.${RESET} Use an existing Node ID"
            echo ""
            read -rp "Choose option (1 or 2): " node_choice
            
            case $node_choice in
                1)
                    echo -e "${CYAN}✅ Will create a new Node ID${RESET}"
                    build_image
                    run_container "$WALLET_ADDRESS"
                    ;;
                2)
                    echo -e "${CYAN}📝 Please enter your existing Node ID:${RESET}"
                    read -rp "Node ID: " EXISTING_NODE_ID
                    if [[ ! "$EXISTING_NODE_ID" =~ ^[0-9]+$ ]]; then
                        echo -e "${RED}❌ Invalid Node ID format. Must be numeric.${RESET}"
                        read -p "Press enter..."
                        continue
                    fi
                    echo -e "${CYAN}✅ Using existing Node ID: $EXISTING_NODE_ID${RESET}"
                    build_image_existing_node
                    run_container_existing_node "$WALLET_ADDRESS" "$EXISTING_NODE_ID"
                    ;;
                *)
                    echo -e "${RED}❌ Invalid choice. Creating new Node ID.${RESET}"
                    build_image
                    run_container "$WALLET_ADDRESS"
                    ;;
            esac
            
            read -p "Press enter..."
            ;;
        2) list_nodes ;;
        3) batch_uninstall_nodes ;;
        4) view_logs ;;
        5) uninstall_all_nodes ;;
        6) restart_all_nodes ;;
        7) update_all_nodes ;;
        8) clear_all_logs ;;
        9) 
            check_cron
            setup_auto_restart
            read -p "Press enter..."
            ;;
        10) 
            remove_auto_restart
            read -p "Press enter..."
            ;;
        *) echo "Invalid option."; read -p "Press enter..." ;;
    esac
done
