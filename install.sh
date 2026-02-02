#!/bin/bash
#===============================================================================
#  paqet Tunnel Installer
#  Raw packet-level tunneling for bypassing network restrictions
#  
#  Usage: bash <(curl -fsSL https://raw.githubusercontent.com/g3ntrix/paqet-tunnel/main/install.sh)
#  
#  This script downloads paqet binary from: https://github.com/hanselime/paqet
#===============================================================================

set -e

# Configuration
INSTALLER_VERSION="1.3.0"
PAQET_VERSION="latest"
PAQET_DIR="/opt/paqet"
PAQET_CONFIG="$PAQET_DIR/config.yaml"
PAQET_BIN="$PAQET_DIR/paqet"
PAQET_SERVICE="paqet"
GITHUB_REPO="hanselime/paqet"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

print_banner() {
    clear
    echo -e "${MAGENTA}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║     ██████╗  █████╗  ██████╗ ███████╗████████╗               ║"
    echo "║     ██╔══██╗██╔══██╗██╔═══██╗██╔════╝╚══██╔══╝               ║"
    echo "║     ██████╔╝███████║██║   ██║█████╗     ██║                  ║"
    echo "║     ██╔═══╝ ██╔══██║██║▄▄ ██║██╔══╝     ██║                  ║"
    echo "║     ██║     ██║  ██║╚██████╔╝███████╗   ██║                  ║"
    echo "║     ╚═╝     ╚═╝  ╚═╝ ╚══▀▀═╝ ╚══════╝   ╚═╝                  ║"
    echo "║                                                              ║"
    echo "║          Raw Packet Tunnel - Firewall Bypass                 ║"
    echo "║                      v${INSTALLER_VERSION}                                  ║"
    echo "║                                                              ║"
    echo "║                      Created by g3ntrix                      ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_step() { echo -e "${BLUE}[*]${NC} $1"; }
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_info() { echo -e "${CYAN}[i]${NC} $1"; }

#===============================================================================
# System Detection Functions
#===============================================================================

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "Please run as root"
        exit 1
    fi
}

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    elif [ -f /etc/redhat-release ]; then
        OS="rhel"
    else
        OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    fi
    echo "$OS"
}

detect_arch() {
    local arch=$(uname -m)
    case $arch in
        x86_64)  echo "amd64" ;;
        aarch64) echo "arm64" ;;
        armv7l)  echo "arm" ;;
        *)       echo "$arch" ;;
    esac
}

get_public_ip() {
    local ip=""
    ip=$(curl -4 -s --max-time 3 ifconfig.me 2>/dev/null) || \
    ip=$(curl -4 -s --max-time 3 icanhazip.com 2>/dev/null) || \
    ip=$(curl -4 -s --max-time 3 api.ipify.org 2>/dev/null) || \
    ip=$(hostname -I | awk '{print $1}')
    
    if echo "$ip" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
        echo "$ip"
    else
        hostname -I | awk '{print $1}'
    fi
}

get_local_ip() {
    local interface=$1
    ip -4 addr show "$interface" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1
}

get_default_interface() {
    ip route | grep default | awk '{print $5}' | head -1
}

get_gateway_ip() {
    ip route | grep default | awk '{print $3}' | head -1
}

get_gateway_mac() {
    local gateway_ip=$(get_gateway_ip)
    if [ -n "$gateway_ip" ]; then
        # Ping to populate neighbor cache
        ping -c 1 -W 1 "$gateway_ip" >/dev/null 2>&1 || true
        
        # Try ip neigh first (modern method)
        local mac=$(ip neigh show "$gateway_ip" 2>/dev/null | grep -oE '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}' | head -1)
        
        # Fallback to arp if ip neigh fails
        if [ -z "$mac" ] && command -v arp >/dev/null 2>&1; then
            mac=$(arp -n "$gateway_ip" 2>/dev/null | grep -oE '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}' | head -1)
        fi
        
        echo "$mac"
    fi
}

check_port_conflict() {
    local port=$1
    local pid=""
    
    if ss -tuln | grep -q ":${port} "; then
        print_warning "Port $port is already in use!"
        
        pid=$(lsof -t -i:$port 2>/dev/null | head -1)
        if [ -n "$pid" ]; then
            local pname=$(ps -p $pid -o comm= 2>/dev/null)
            echo -e "  Process: ${CYAN}$pname${NC} (PID: $pid)"
            echo ""
            echo -e "${YELLOW}Kill this process? (y/n)${NC}"
            read -p "> " kill_choice < /dev/tty
            
            if [[ "$kill_choice" =~ ^[Yy]$ ]]; then
                kill -9 $pid 2>/dev/null || true
                sleep 1
                pkill -9 -f ".*:${port}" 2>/dev/null || true
                print_success "Process killed"
            else
                print_error "Cannot continue with port in use"
                exit 1
            fi
        fi
    fi
}

#===============================================================================
# Installation Functions
#===============================================================================

install_dependencies() {
    print_step "Installing dependencies..."
    
    echo -e "${YELLOW}Install dependencies? (y/n/s to skip)${NC}"
    echo -e "${CYAN}Required: libpcap-dev, iptables, curl${NC}"
    read -t 10 -p "> " install_deps < /dev/tty || install_deps="y"
    
    if [[ "$install_deps" =~ ^[Ss]$ ]]; then
        print_warning "Skipping dependency installation"
        print_info "Make sure these are installed: libpcap-dev iptables curl"
        return 0
    fi
    
    if [[ ! "$install_deps" =~ ^[Yy]$ ]] && [ -n "$install_deps" ]; then
        print_warning "Skipping dependency installation"
        return 0
    fi
    
    local os=$(detect_os)
    case $os in
        ubuntu|debian)
            print_info "Running apt update (may take time)..."
            timeout 30 apt update -qq 2>/dev/null || {
                print_warning "apt update timed out or failed"
                print_info "Continuing anyway..."
            }
            
            print_info "Installing packages..."
            apt install -y -qq curl wget libpcap-dev iptables lsof > /dev/null 2>&1 || {
                print_warning "Some packages may have failed to install"
                print_info "Continuing anyway..."
            }
            ;;
        centos|rhel|fedora|rocky|almalinux)
            yum install -y -q curl wget libpcap-devel iptables lsof > /dev/null 2>&1 || {
                print_warning "Some packages may have failed to install"
            }
            ;;
        *)
            print_warning "Unknown OS. Please install libpcap manually."
            ;;
    esac
    
    print_success "Dependency installation completed"
}

download_paqet() {
    print_step "Downloading paqet binary..."
    
    local arch=$(detect_arch)
    local os="linux"
    
    mkdir -p "$PAQET_DIR"
    
    # Get the latest version tag
    local version=""
    if [ "$PAQET_VERSION" = "latest" ]; then
        version=$(curl -s https://api.github.com/repos/${GITHUB_REPO}/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
        if [ -z "$version" ]; then
            print_warning "Failed to get latest version from GitHub"
            version="v1.0.0-alpha.11"  # Fallback version
        fi
    else
        version="$PAQET_VERSION"
    fi
    
    # Construct download URL for tar.gz
    local archive_name="paqet-${os}-${arch}-${version}.tar.gz"
    local download_url="https://github.com/${GITHUB_REPO}/releases/download/${version}/${archive_name}"
    
    print_info "Downloading version: $version"
    print_info "URL: $download_url"
    
    # Check for local file in /root/paqet first
    local local_dir="/root/paqet"
    local local_archive="$local_dir/$archive_name"
    
    # Download and extract
    local temp_archive="/tmp/paqet.tar.gz"
    local download_success=false
    
    if [ -f "$local_archive" ]; then
        print_success "Found local file: $local_archive"
        cp "$local_archive" "$temp_archive"
        download_success=true
    elif [ -d "$local_dir" ] && [ "$(ls -A $local_dir/*.tar.gz 2>/dev/null)" ]; then
        # Found some tar.gz in /root/paqet, ask user
        print_info "Found archives in $local_dir:"
        ls -1 "$local_dir"/*.tar.gz 2>/dev/null
        echo ""
        echo -e "${YELLOW}Use one of these files? (y/n)${NC}"
        read -p "> " use_local < /dev/tty
        
        if [[ "$use_local" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Enter the filename (or full path):${NC}"
            read -p "> " user_file < /dev/tty
            
            # Check if it's a full path or just filename
            if [ -f "$user_file" ]; then
                local_archive="$user_file"
            elif [ -f "$local_dir/$user_file" ]; then
                local_archive="$local_dir/$user_file"
            else
                print_error "File not found: $user_file"
                exit 1
            fi
            
            cp "$local_archive" "$temp_archive"
            download_success=true
            print_success "Using local file: $local_archive"
        fi
    fi
    
    # Try downloading if no local file was used
    if [ "$download_success" = false ]; then
        print_info "Attempting download..."
        if timeout 30 curl -fsSL "$download_url" -o "$temp_archive" 2>/dev/null; then
            download_success=true
            print_success "Download completed"
        else
            print_error "Failed to download paqet binary"
            print_warning "Download blocked or network issue detected"
            echo ""
            echo -e "${YELLOW}Do you have a local copy of the paqet archive? (y/n)${NC}"
            read -p "> " has_local < /dev/tty
            
            if [[ "$has_local" =~ ^[Yy]$ ]]; then
                echo -e "${YELLOW}Enter the full path to the paqet tar.gz file:${NC}"
                echo -e "${CYAN}Example: /root/paqet/paqet-linux-amd64-v1.0.0-alpha.11.tar.gz${NC}"
                read -p "> " local_archive < /dev/tty
                
                if [ -f "$local_archive" ]; then
                    cp "$local_archive" "$temp_archive"
                    download_success=true
                    print_success "Using local file: $local_archive"
                else
                    print_error "File not found: $local_archive"
                    exit 1
                fi
            else
                print_info "Please download manually from: https://github.com/${GITHUB_REPO}/releases"
                print_info "Save to: $local_dir/"
                print_info "Then run this installer again"
                exit 1
            fi
        fi
    fi
    
    if [ "$download_success" = true ]; then
        # Extract the binary
        tar -xzf "$temp_archive" -C "$PAQET_DIR" 2>/dev/null || {
            print_error "Failed to extract archive"
            rm -f "$temp_archive"
            exit 1
        }
        
        # The extracted binary is named paqet_<os>_<arch>, rename it to paqet
        local extracted_binary="$PAQET_DIR/paqet_${os}_${arch}"
        if [ -f "$extracted_binary" ]; then
            mv "$extracted_binary" "$PAQET_BIN"
            chmod +x "$PAQET_BIN"
            rm -f "$temp_archive"
            # Clean up example files
            rm -rf "$PAQET_DIR/README.md" "$PAQET_DIR/example" 2>/dev/null || true
            print_success "paqet binary installed successfully"
        else
            print_error "Binary not found in archive"
            print_info "Expected: $extracted_binary"
            ls -la "$PAQET_DIR"
            rm -f "$temp_archive"
            exit 1
        fi
    fi
}

generate_secret_key() {
    # Generate a random 32-character key
    if command -v openssl &> /dev/null; then
        openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 32
    else
        cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 32
    fi
}

setup_iptables() {
    local port=$1
    print_step "Configuring iptables for port $port..."
    
    # Remove existing rules if any
    iptables -t raw -D PREROUTING -p tcp --dport $port -j NOTRACK 2>/dev/null || true
    iptables -t raw -D OUTPUT -p tcp --sport $port -j NOTRACK 2>/dev/null || true
    iptables -t mangle -D OUTPUT -p tcp --sport $port --tcp-flags RST RST -j DROP 2>/dev/null || true
    
    # Add new rules
    iptables -t raw -A PREROUTING -p tcp --dport $port -j NOTRACK
    iptables -t raw -A OUTPUT -p tcp --sport $port -j NOTRACK
    iptables -t mangle -A OUTPUT -p tcp --sport $port --tcp-flags RST RST -j DROP
    
    # Save iptables rules
    if command -v iptables-save &> /dev/null; then
        if [ -d /etc/iptables ]; then
            iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
        elif [ -f /etc/sysconfig/iptables ]; then
            iptables-save > /etc/sysconfig/iptables 2>/dev/null || true
        fi
    fi
    
    print_success "iptables configured"
}

create_systemd_service() {
    print_step "Creating systemd service..."
    
    cat > /etc/systemd/system/${PAQET_SERVICE}.service << EOF
[Unit]
Description=paqet Raw Packet Tunnel
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
ExecStart=${PAQET_BIN} run -c ${PAQET_CONFIG}
Restart=always
RestartSec=5
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    print_success "Systemd service created"
}

#===============================================================================
# Server B Setup (Abroad - VPN Server with paqet server)
#===============================================================================

setup_server_b() {
    print_banner
    echo -e "${GREEN}Setting up Server B (Abroad - VPN Server)${NC}"
    echo -e "${CYAN}This server runs your V2Ray/X-UI and the paqet server${NC}"
    echo ""
    
    # Detect network configuration
    local interface=$(get_default_interface)
    local local_ip=$(get_local_ip "$interface")
    local public_ip=$(get_public_ip)
    local gateway_mac=$(get_gateway_mac)
    
    echo -e "${YELLOW}Network Configuration Detected:${NC}"
    echo -e "  Interface:   ${CYAN}$interface${NC}"
    echo -e "  Local IP:    ${CYAN}$local_ip${NC}"
    echo -e "  Public IP:   ${CYAN}$public_ip${NC}"
    echo -e "  Gateway MAC: ${CYAN}$gateway_mac${NC}"
    echo ""
    
    # Confirm or modify interface
    echo -e "${YELLOW}Network interface [${interface}]:${NC}"
    read -p "> " input_interface < /dev/tty
    [ -n "$input_interface" ] && interface="$input_interface"
    
    # Get local IP for that interface
    local_ip=$(get_local_ip "$interface")
    if [ -z "$local_ip" ]; then
        echo -e "${YELLOW}Could not detect IP. Enter local IP:${NC}"
        read -p "> " local_ip < /dev/tty
    fi
    
    # Confirm gateway MAC
    if [ -z "$gateway_mac" ]; then
        echo -e "${YELLOW}Could not detect gateway MAC. Enter gateway MAC address:${NC}"
        read -p "> " gateway_mac < /dev/tty
    else
        echo -e "${YELLOW}Gateway MAC [${gateway_mac}]:${NC}"
        read -p "> " input_mac < /dev/tty
        [ -n "$input_mac" ] && gateway_mac="$input_mac"
    fi
    
    # paqet listen port
    echo ""
    echo -e "${YELLOW}Enter paqet listen port (for tunnel, NOT your V2Ray ports):${NC}"
    read -p "Port [8888]: " PAQET_PORT < /dev/tty
    [ -z "$PAQET_PORT" ] && PAQET_PORT="8888"
    
    # Check port conflict
    check_port_conflict "$PAQET_PORT"
    
    # V2Ray ports to forward
    echo ""
    echo -e "${YELLOW}Enter V2Ray inbound ports (comma-separated):${NC}"
    echo -e "${CYAN}These are the ports your V2Ray/X-UI listens on${NC}"
    read -p "Ports [9090]: " INBOUND_PORTS < /dev/tty
    [ -z "$INBOUND_PORTS" ] && INBOUND_PORTS="9090"
    
    # Generate or input secret key
    echo ""
    local secret_key=$(generate_secret_key)
    echo -e "${YELLOW}Generated secret key (or enter your own):${NC}"
    echo -e "${CYAN}$secret_key${NC}"
    read -p "Key [$secret_key]: " input_key < /dev/tty
    [ -n "$input_key" ] && secret_key="$input_key"
    
    # Download paqet
    download_paqet
    
    # Setup iptables
    setup_iptables "$PAQET_PORT"
    
    # Create config file
    print_step "Creating configuration..."
    
    cat > "$PAQET_CONFIG" << EOF
# paqet Server Configuration
# Generated by installer on $(date)
role: "server"

log:
  level: "info"

listen:
  addr: ":${PAQET_PORT}"

network:
  interface: "${interface}"
  ipv4:
    addr: "${local_ip}:${PAQET_PORT}"
    router_mac: "${gateway_mac}"
  tcp:
    local_flag: ["PA"]

transport:
  protocol: "kcp"
  conn: 1
  kcp:
    mode: "fast"
    key: "${secret_key}"
EOF
    
    print_success "Configuration created"
    
    # Create systemd service
    create_systemd_service
    
    # Start service
    systemctl enable --now $PAQET_SERVICE
    
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}                 Server B Ready!                            ${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${YELLOW}Public IP:${NC}     ${CYAN}$public_ip${NC}"
    echo -e "  ${YELLOW}paqet Port:${NC}    ${CYAN}$PAQET_PORT${NC}"
    echo -e "  ${YELLOW}V2Ray Ports:${NC}   ${CYAN}$INBOUND_PORTS${NC}"
    echo ""
    echo -e "${YELLOW}Secret Key (save this for Server A):${NC}"
    echo -e "${CYAN}$secret_key${NC}"
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo -e "  1. Make sure V2Ray/X-UI is running on ports: ${CYAN}$INBOUND_PORTS${NC}"
    echo -e "  2. Run this installer on Server A with same secret key"
    echo -e "  3. Open port ${CYAN}$PAQET_PORT${NC} in cloud firewall (if any)"
    echo ""
    echo -e "${YELLOW}Commands:${NC}"
    echo -e "  Status:  ${CYAN}systemctl status $PAQET_SERVICE${NC}"
    echo -e "  Logs:    ${CYAN}journalctl -u $PAQET_SERVICE -f${NC}"
    echo -e "  Restart: ${CYAN}systemctl restart $PAQET_SERVICE${NC}"
    echo ""
}

#===============================================================================
# Server A Setup (Entry Point - paqet client with port forwarding)
#===============================================================================

setup_server_a() {
    print_banner
    echo -e "${GREEN}Setting up Server A (Entry Point)${NC}"
    echo -e "${CYAN}This server accepts client connections and tunnels to Server B${NC}"
    echo ""
    
    # Detect network configuration
    local interface=$(get_default_interface)
    local local_ip=$(get_local_ip "$interface")
    local public_ip=$(get_public_ip)
    local gateway_mac=$(get_gateway_mac)
    
    echo -e "${YELLOW}Network Configuration Detected:${NC}"
    echo -e "  Interface:   ${CYAN}$interface${NC}"
    echo -e "  Local IP:    ${CYAN}$local_ip${NC}"
    echo -e "  Public IP:   ${CYAN}$public_ip${NC}"
    echo -e "  Gateway MAC: ${CYAN}$gateway_mac${NC}"
    echo ""
    
    # Get Server B details
    echo -e "${YELLOW}Enter Server B (Abroad) public IP:${NC}"
    read -p "IP: " SERVER_B_IP < /dev/tty
    [ -z "$SERVER_B_IP" ] && { print_error "Server B IP required"; exit 1; }
    
    echo ""
    echo -e "${YELLOW}Enter paqet port on Server B:${NC}"
    read -p "Port [8888]: " SERVER_B_PORT < /dev/tty
    [ -z "$SERVER_B_PORT" ] && SERVER_B_PORT="8888"
    
    echo ""
    echo -e "${YELLOW}Enter secret key (from Server B setup):${NC}"
    read -p "Key: " SECRET_KEY < /dev/tty
    [ -z "$SECRET_KEY" ] && { print_error "Secret key required"; exit 1; }
    
    # Confirm or modify interface
    echo ""
    echo -e "${YELLOW}Network interface [${interface}]:${NC}"
    read -p "> " input_interface < /dev/tty
    [ -n "$input_interface" ] && interface="$input_interface"
    
    # Get local IP for that interface
    local_ip=$(get_local_ip "$interface")
    if [ -z "$local_ip" ]; then
        echo -e "${YELLOW}Could not detect IP. Enter local IP:${NC}"
        read -p "> " local_ip < /dev/tty
    fi
    
    # Confirm gateway MAC
    if [ -z "$gateway_mac" ]; then
        echo -e "${YELLOW}Could not detect gateway MAC. Enter gateway MAC address:${NC}"
        read -p "> " gateway_mac < /dev/tty
    else
        echo -e "${YELLOW}Gateway MAC [${gateway_mac}]:${NC}"
        read -p "> " input_mac < /dev/tty
        [ -n "$input_mac" ] && gateway_mac="$input_mac"
    fi
    
    # Ports to forward
    echo ""
    echo -e "${YELLOW}Enter ports to forward (comma-separated):${NC}"
    echo -e "${CYAN}These will be accessible on this server and forwarded to Server B${NC}"
    read -p "Ports [9090]: " FORWARD_PORTS < /dev/tty
    [ -z "$FORWARD_PORTS" ] && FORWARD_PORTS="9090"
    
    # Check port conflicts
    echo ""
    IFS=',' read -ra PORTS <<< "$FORWARD_PORTS"
    for port in "${PORTS[@]}"; do
        port=$(echo "$port" | tr -d ' ')
        check_port_conflict "$port"
    done
    
    # Download paqet
    download_paqet
    
    # Create forward configuration
    print_step "Creating configuration..."
    
    # Build forward section
    local forward_config=""
    for port in "${PORTS[@]}"; do
        port=$(echo "$port" | tr -d ' ')
        forward_config="${forward_config}
  - listen: \"0.0.0.0:${port}\"
    target: \"127.0.0.1:${port}\"
    protocol: \"tcp\""
    done
    
    cat > "$PAQET_CONFIG" << EOF
# paqet Client Configuration (Port Forwarding Mode)
# Generated by installer on $(date)
role: "client"

log:
  level: "info"

# Port forwarding - accepts connections and forwards through tunnel
forward:${forward_config}

network:
  interface: "${interface}"
  ipv4:
    addr: "${local_ip}:0"
    router_mac: "${gateway_mac}"
  tcp:
    local_flag: ["PA"]
    remote_flag: ["PA"]

server:
  addr: "${SERVER_B_IP}:${SERVER_B_PORT}"

transport:
  protocol: "kcp"
  conn: 1
  kcp:
    mode: "fast"
    key: "${SECRET_KEY}"
EOF
    
    print_success "Configuration created"
    
    # Create systemd service
    create_systemd_service
    
    # Start service
    systemctl enable --now $PAQET_SERVICE
    
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}                 Server A Ready!                            ${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${YELLOW}This Server:${NC}   ${CYAN}$public_ip${NC}"
    echo -e "  ${YELLOW}Server B:${NC}      ${CYAN}$SERVER_B_IP:$SERVER_B_PORT${NC}"
    echo -e "  ${YELLOW}Forwarding:${NC}    ${CYAN}$FORWARD_PORTS${NC}"
    echo ""
    echo -e "${YELLOW}Client Connection:${NC}"
    echo -e "  Clients should connect to: ${CYAN}$public_ip${NC}"
    echo -e "  On ports: ${CYAN}$FORWARD_PORTS${NC}"
    echo ""
    echo -e "${YELLOW}Example V2Ray config update:${NC}"
    for port in "${PORTS[@]}"; do
        port=$(echo "$port" | tr -d ' ')
        echo -e "  Change: ${RED}vless://...@${SERVER_B_IP}:${port}${NC}"
        echo -e "  To:     ${GREEN}vless://...@${public_ip}:${port}${NC}"
    done
    echo ""
    echo -e "${YELLOW}Commands:${NC}"
    echo -e "  Status:  ${CYAN}systemctl status $PAQET_SERVICE${NC}"
    echo -e "  Logs:    ${CYAN}journalctl -u $PAQET_SERVICE -f${NC}"
    echo -e "  Restart: ${CYAN}systemctl restart $PAQET_SERVICE${NC}"
    echo ""
}

#===============================================================================
# Status Check
#===============================================================================

check_status() {
    print_banner
    echo -e "${YELLOW}paqet Status${NC}"
    echo ""
    
    # Service status
    if systemctl is-active --quiet $PAQET_SERVICE 2>/dev/null; then
        echo -e "Service: ${GREEN}● Running${NC}"
        local uptime=$(systemctl show $PAQET_SERVICE --property=ActiveEnterTimestamp 2>/dev/null | cut -d'=' -f2)
        [ -n "$uptime" ] && echo -e "Started: ${CYAN}$uptime${NC}"
    else
        echo -e "Service: ${RED}● Stopped${NC}"
    fi
    
    echo ""
    
    # Configuration
    if [ -f "$PAQET_CONFIG" ]; then
        echo -e "${YELLOW}Configuration:${NC}"
        local role=$(grep "^role:" "$PAQET_CONFIG" 2>/dev/null | awk '{print $2}' | tr -d '"')
        echo -e "  Role: ${CYAN}$role${NC}"
        
        if [ "$role" = "server" ]; then
            local listen=$(grep "addr:" "$PAQET_CONFIG" 2>/dev/null | head -1 | awk '{print $2}' | tr -d '"')
            echo -e "  Listen: ${CYAN}$listen${NC}"
        else
            local server=$(grep -A1 "^server:" "$PAQET_CONFIG" 2>/dev/null | grep "addr:" | awk '{print $2}' | tr -d '"')
            echo -e "  Server: ${CYAN}$server${NC}"
        fi
    else
        echo -e "${YELLOW}Configuration:${NC} ${RED}Not found${NC}"
    fi
    
    echo ""
    
    # Listening ports
    echo -e "${YELLOW}Listening Ports:${NC}"
    ss -tuln 2>/dev/null | grep -E "LISTEN" | awk '{print "  "$5}' | head -10 || echo "  None"
    
    echo ""
    
    # Recent logs
    echo -e "${YELLOW}Recent Logs:${NC}"
    journalctl -u $PAQET_SERVICE -n 5 --no-pager 2>/dev/null || echo "  No logs available"
    
    echo ""
}

#===============================================================================
# Uninstall
#===============================================================================

uninstall() {
    print_banner
    echo -e "${YELLOW}Uninstalling paqet...${NC}"
    echo ""
    
    # Stop and disable service
    print_step "Stopping service..."
    systemctl stop $PAQET_SERVICE 2>/dev/null || true
    systemctl disable $PAQET_SERVICE 2>/dev/null || true
    rm -f /etc/systemd/system/${PAQET_SERVICE}.service
    systemctl daemon-reload
    print_success "Service removed"
    
    # Remove iptables rules (try common ports)
    print_step "Removing iptables rules..."
    for port in 8888 9999 8080; do
        iptables -t raw -D PREROUTING -p tcp --dport $port -j NOTRACK 2>/dev/null || true
        iptables -t raw -D OUTPUT -p tcp --sport $port -j NOTRACK 2>/dev/null || true
        iptables -t mangle -D OUTPUT -p tcp --sport $port --tcp-flags RST RST -j DROP 2>/dev/null || true
    done
    print_success "iptables rules removed"
    
    # Ask about config preservation
    echo ""
    echo -e "${YELLOW}Remove configuration and binary? (y/n)${NC}"
    read -p "> " remove_all < /dev/tty
    
    if [[ "$remove_all" =~ ^[Yy]$ ]]; then
        rm -rf "$PAQET_DIR"
        print_success "All files removed"
    else
        print_warning "Configuration preserved at: $PAQET_CONFIG"
    fi
    
    echo ""
    print_success "paqet uninstalled"
    echo ""
}

#===============================================================================
# View/Edit Configuration
#===============================================================================

view_config() {
    print_banner
    echo -e "${YELLOW}Current Configuration${NC}"
    echo ""
    
    if [ -f "$PAQET_CONFIG" ]; then
        cat "$PAQET_CONFIG"
    else
        print_error "Configuration not found at $PAQET_CONFIG"
    fi
    
    echo ""
    echo -e "${YELLOW}Press Enter to continue...${NC}"
    read < /dev/tty
}

#===============================================================================
# Main Menu
#===============================================================================

main() {
    check_root
    
    while true; do
        print_banner
        
        echo -e "${YELLOW}Select option:${NC}"
        echo ""
        echo -e "  ${CYAN}1)${NC} Setup Server B (Abroad - VPN server)"
        echo -e "  ${CYAN}2)${NC} Setup Server A (Iran - entry point)"
        echo -e "  ${CYAN}3)${NC} Check Status"
        echo -e "  ${CYAN}4)${NC} View Configuration"
        echo -e "  ${CYAN}5)${NC} Uninstall"
        echo -e "  ${CYAN}6)${NC} Exit"
        echo ""
        read -p "Choice [1-6]: " choice < /dev/tty
        
        case $choice in
            1) install_dependencies; setup_server_b ;;
            2) install_dependencies; setup_server_a ;;
            3) check_status ;;
            4) view_config ;;
            5) uninstall ;;
            6) exit 0 ;;
            *) print_error "Invalid choice" ;;
        esac
        
        echo ""
        echo -e "${YELLOW}Press Enter to continue...${NC}"
        read < /dev/tty
    done
}

main "$@"
