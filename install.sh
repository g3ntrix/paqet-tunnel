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
INSTALLER_VERSION="1.5.0"
PAQET_VERSION="latest"
PAQET_DIR="/opt/paqet"
PAQET_CONFIG="$PAQET_DIR/config.yaml"
PAQET_BIN="$PAQET_DIR/paqet"
PAQET_SERVICE="paqet"
GITHUB_REPO="hanselime/paqet"
INSTALLER_REPO="g3ntrix/paqet-tunnel"

#===============================================================================
# Default Port Configuration (Easy to change)
#===============================================================================
DEFAULT_PAQET_PORT="8888"           # Port for paqet tunnel communication
DEFAULT_FORWARD_PORTS="9090"        # Default ports to forward (comma-separated)
DEFAULT_KCP_MODE="fast"             # KCP mode: normal, fast, fast2, fast3
DEFAULT_KCP_CONN="1"                # Number of parallel connections

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
# Input Validation Functions (with retry on invalid input)
#===============================================================================

# Read required input - keeps asking until valid input is provided
# Usage: read_required "prompt" "variable_name" ["default_value"]
read_required() {
    local prompt="$1"
    local varname="$2"
    local default="$3"
    local value=""
    
    while true; do
        if [ -n "$default" ]; then
            echo -e "${YELLOW}${prompt} [${default}]:${NC}"
        else
            echo -e "${YELLOW}${prompt}:${NC}"
        fi
        read -p "> " value < /dev/tty
        
        # Use default if provided and input is empty
        if [ -z "$value" ] && [ -n "$default" ]; then
            value="$default"
        fi
        
        # Validate non-empty
        if [ -n "$value" ]; then
            eval "$varname='$value'"
            return 0
        else
            print_error "This field is required. Please enter a value."
            echo ""
        fi
    done
}

# Read IP address with validation
# Usage: read_ip "prompt" "variable_name" ["default_value"]
read_ip() {
    local prompt="$1"
    local varname="$2"
    local default="$3"
    local value=""
    local ip_regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    
    while true; do
        if [ -n "$default" ]; then
            echo -e "${YELLOW}${prompt} [${default}]:${NC}"
        else
            echo -e "${YELLOW}${prompt}:${NC}"
        fi
        read -p "> " value < /dev/tty
        
        # Use default if provided and input is empty
        if [ -z "$value" ] && [ -n "$default" ]; then
            value="$default"
        fi
        
        # Validate IP format
        if [ -z "$value" ]; then
            print_error "IP address is required. Please enter a valid IP."
            echo ""
        elif ! [[ "$value" =~ $ip_regex ]]; then
            print_error "Invalid IP format. Please enter a valid IPv4 address (e.g., 192.168.1.1)"
            echo ""
        else
            eval "$varname='$value'"
            return 0
        fi
    done
}

# Read port number with validation
# Usage: read_port "prompt" "variable_name" ["default_value"]
read_port() {
    local prompt="$1"
    local varname="$2"
    local default="$3"
    local value=""
    
    while true; do
        if [ -n "$default" ]; then
            echo -e "${YELLOW}${prompt} [${default}]:${NC}"
        else
            echo -e "${YELLOW}${prompt}:${NC}"
        fi
        read -p "> " value < /dev/tty
        
        # Use default if provided and input is empty
        if [ -z "$value" ] && [ -n "$default" ]; then
            value="$default"
        fi
        
        # Validate port number
        if [ -z "$value" ]; then
            print_error "Port number is required."
            echo ""
        elif ! [[ "$value" =~ ^[0-9]+$ ]]; then
            print_error "Invalid port. Please enter a number."
            echo ""
        elif [ "$value" -lt 1 ] || [ "$value" -gt 65535 ]; then
            print_error "Port must be between 1 and 65535."
            echo ""
        else
            eval "$varname='$value'"
            return 0
        fi
    done
}

# Read port list with validation (comma-separated)
# Usage: read_ports "prompt" "variable_name" ["default_value"]
read_ports() {
    local prompt="$1"
    local varname="$2"
    local default="$3"
    local value=""
    
    while true; do
        if [ -n "$default" ]; then
            echo -e "${YELLOW}${prompt} [${default}]:${NC}"
        else
            echo -e "${YELLOW}${prompt}:${NC}"
        fi
        read -p "> " value < /dev/tty
        
        # Use default if provided and input is empty
        if [ -z "$value" ] && [ -n "$default" ]; then
            value="$default"
        fi
        
        # Validate port list
        if [ -z "$value" ]; then
            print_error "At least one port is required."
            echo ""
            continue
        fi
        
        # Validate each port in the comma-separated list
        local valid=true
        IFS=',' read -ra ports <<< "$value"
        for port in "${ports[@]}"; do
            port=$(echo "$port" | tr -d ' ')
            if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
                print_error "Invalid port: $port. Each port must be a number between 1-65535."
                valid=false
                break
            fi
        done
        
        if [ "$valid" = true ]; then
            eval "$varname='$value'"
            return 0
        fi
        echo ""
    done
}

# Read MAC address with validation
# Usage: read_mac "prompt" "variable_name" ["default_value"]
read_mac() {
    local prompt="$1"
    local varname="$2"
    local default="$3"
    local value=""
    local mac_regex='^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$'
    
    while true; do
        if [ -n "$default" ]; then
            echo -e "${YELLOW}${prompt} [${default}]:${NC}"
        else
            echo -e "${YELLOW}${prompt}:${NC}"
        fi
        read -p "> " value < /dev/tty
        
        # Use default if provided and input is empty
        if [ -z "$value" ] && [ -n "$default" ]; then
            value="$default"
        fi
        
        # Validate MAC format
        if [ -z "$value" ]; then
            print_error "MAC address is required."
            echo ""
        elif ! [[ "$value" =~ $mac_regex ]]; then
            print_error "Invalid MAC format. Please use format: aa:bb:cc:dd:ee:ff"
            echo ""
        else
            eval "$varname='$value'"
            return 0
        fi
    done
}

# Read yes/no confirmation
# Usage: read_confirm "prompt" "variable_name" ["default_y_or_n"]
read_confirm() {
    local prompt="$1"
    local varname="$2"
    local default="$3"
    local value=""
    
    while true; do
        if [ "$default" = "y" ]; then
            echo -e "${YELLOW}${prompt} (Y/n):${NC}"
        elif [ "$default" = "n" ]; then
            echo -e "${YELLOW}${prompt} (y/N):${NC}"
        else
            echo -e "${YELLOW}${prompt} (y/n):${NC}"
        fi
        read -p "> " value < /dev/tty
        
        # Use default if input is empty and default is provided
        if [ -z "$value" ] && [ -n "$default" ]; then
            value="$default"
        fi
        
        case "$value" in
            [Yy]|[Yy][Ee][Ss]) eval "$varname=true"; return 0 ;;
            [Nn]|[Nn][Oo]) eval "$varname=false"; return 0 ;;
            *) print_error "Please enter 'y' for yes or 'n' for no."; echo "" ;;
        esac
    done
}

# Read optional input - allows empty value
# Usage: read_optional "prompt" "variable_name" ["default_value"]
read_optional() {
    local prompt="$1"
    local varname="$2"
    local default="$3"
    local value=""
    
    if [ -n "$default" ]; then
        echo -e "${YELLOW}${prompt} [${default}]:${NC}"
    else
        echo -e "${YELLOW}${prompt} (optional):${NC}"
    fi
    read -p "> " value < /dev/tty
    
    # Use default if input is empty
    if [ -z "$value" ] && [ -n "$default" ]; then
        value="$default"
    fi
    
    eval "$varname='$value'"
}

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

# Iran server network optimization (DNS + apt mirror selection)
run_iran_optimizations() {
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}          Iran Server Network Optimization                  ${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}These scripts can help optimize your Iran server:${NC}"
    echo -e "  ${YELLOW}1.${NC} DNS Finder - Find the best DNS servers for Iran"
    echo -e "  ${YELLOW}2.${NC} Mirror Selector - Find the fastest apt repository mirror"
    echo ""
    echo -e "${CYAN}This can significantly improve download speeds and reliability.${NC}"
    echo ""
    
    read_confirm "Run network optimization scripts before installation?" run_optimize "y"
    
    if [ "$run_optimize" = true ]; then
        echo ""
        
        # Run DNS optimization
        print_step "Running DNS Finder..."
        print_info "This will find and configure the best DNS for Iran"
        echo ""
        if bash <(curl -Ls https://github.com/alinezamifar/IranDNSFinder/raw/refs/heads/main/dns.sh); then
            print_success "DNS optimization completed"
        else
            print_warning "DNS optimization failed or was skipped"
        fi
        
        echo ""
        
        # Run apt mirror optimization (only for Debian/Ubuntu)
        local os=$(detect_os)
        if [[ "$os" == "ubuntu" ]] || [[ "$os" == "debian" ]]; then
            print_step "Running Ubuntu/Debian Mirror Selector..."
            print_info "This will find the fastest apt repository mirror"
            echo ""
            if bash <(curl -Ls https://github.com/alinezamifar/DetectUbuntuMirror/raw/refs/heads/main/DUM.sh); then
                print_success "Mirror optimization completed"
            else
                print_warning "Mirror optimization failed or was skipped"
            fi
        else
            print_info "Mirror selector is only available for Ubuntu/Debian"
        fi
        
        echo ""
        print_success "Network optimization completed!"
        echo ""
    else
        print_info "Skipping network optimization"
    fi
}

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
    
    # Confirm or modify interface (with validation)
    read_required "Network interface" interface "$interface"
    
    # Get local IP for that interface (with validation)
    local_ip=$(get_local_ip "$interface")
    if [ -z "$local_ip" ]; then
        read_ip "Could not detect IP. Enter local IP" local_ip
    else
        read_optional "Local IP" local_ip "$local_ip"
    fi
    
    # Confirm gateway MAC (with validation)
    if [ -z "$gateway_mac" ]; then
        read_mac "Could not detect gateway MAC. Enter gateway MAC address" gateway_mac
    else
        read_optional "Gateway MAC" input_mac "$gateway_mac"
        [ -n "$input_mac" ] && gateway_mac="$input_mac"
    fi
    
    # paqet listen port (with validation)
    echo ""
    echo -e "${CYAN}Enter paqet listen port (for tunnel, NOT your V2Ray ports)${NC}"
    read_port "paqet listen port" PAQET_PORT "$DEFAULT_PAQET_PORT"
    
    # Check port conflict
    check_port_conflict "$PAQET_PORT"
    
    # V2Ray ports to forward (with validation)
    echo ""
    echo -e "${CYAN}These are the ports your V2Ray/X-UI listens on${NC}"
    read_ports "Enter V2Ray inbound ports (comma-separated)" INBOUND_PORTS "$DEFAULT_FORWARD_PORTS"
    
    # Generate or input secret key
    echo ""
    local secret_key=$(generate_secret_key)
    echo -e "${CYAN}Generated secret key: $secret_key${NC}"
    read_required "Secret key (press Enter to use generated)" secret_key "$secret_key"
    
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
    
    # Get Server B details (with validation - keeps asking until valid)
    echo -e "${CYAN}Enter Server B (Abroad) connection details${NC}"
    read_ip "Server B public IP address" SERVER_B_IP
    
    echo ""
    read_port "paqet port on Server B" SERVER_B_PORT "$DEFAULT_PAQET_PORT"
    
    echo ""
    read_required "Secret key (from Server B setup)" SECRET_KEY
    
    # Confirm or modify interface (with validation)
    echo ""
    read_required "Network interface" interface "$interface"
    
    # Get local IP for that interface (with validation)
    local_ip=$(get_local_ip "$interface")
    if [ -z "$local_ip" ]; then
        read_ip "Could not detect IP. Enter local IP" local_ip
    else
        read_optional "Local IP" local_ip "$local_ip"
    fi
    
    # Confirm gateway MAC (with validation)
    if [ -z "$gateway_mac" ]; then
        read_mac "Could not detect gateway MAC. Enter gateway MAC address" gateway_mac
    else
        read_optional "Gateway MAC" input_mac "$gateway_mac"
        [ -n "$input_mac" ] && gateway_mac="$input_mac"
    fi
    
    # Ports to forward (with validation)
    echo ""
    echo -e "${CYAN}These will be accessible on this server and forwarded to Server B${NC}"
    read_ports "Enter ports to forward (comma-separated)" FORWARD_PORTS "$DEFAULT_FORWARD_PORTS"
    
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
# Edit Configuration
#===============================================================================

edit_config() {
    print_banner
    echo -e "${YELLOW}Edit Configuration${NC}"
    echo ""
    
    if [ ! -f "$PAQET_CONFIG" ]; then
        print_error "Configuration not found at $PAQET_CONFIG"
        print_info "Please run setup first"
        return 1
    fi
    
    # Detect current role
    local role=$(grep "^role:" "$PAQET_CONFIG" 2>/dev/null | awk '{print $2}' | tr -d '"')
    
    echo -e "Current role: ${CYAN}$role${NC}"
    echo ""
    echo -e "${YELLOW}What would you like to edit?${NC}"
    echo ""
    echo -e "  ${CYAN}1)${NC} Change ports"
    echo -e "  ${CYAN}2)${NC} Change secret key"
    echo -e "  ${CYAN}3)${NC} Change KCP settings"
    echo -e "  ${CYAN}4)${NC} Change network interface"
    if [ "$role" = "client" ]; then
        echo -e "  ${CYAN}5)${NC} Change Server B address"
    fi
    echo -e "  ${CYAN}0)${NC} Back to main menu"
    echo ""
    
    read -p "Choice: " edit_choice < /dev/tty
    
    case $edit_choice in
        1) edit_ports "$role" ;;
        2) edit_secret_key ;;
        3) edit_kcp_settings ;;
        4) edit_interface ;;
        5) 
            if [ "$role" = "client" ]; then
                edit_server_address
            else
                print_error "Invalid choice"
            fi
            ;;
        0) return 0 ;;
        *) print_error "Invalid choice" ;;
    esac
}

edit_ports() {
    local role=$1
    echo ""
    
    if [ "$role" = "server" ]; then
        local current_port=$(grep -A1 "^listen:" "$PAQET_CONFIG" | grep "addr:" | sed 's/.*:\([0-9]*\)".*/\1/')
        read_port "Enter new paqet listen port" NEW_PORT "$current_port"
        
        # Update config file
        sed -i "s/addr: \":[0-9]*\"/addr: \":${NEW_PORT}\"/" "$PAQET_CONFIG"
        
        # Update iptables
        setup_iptables "$NEW_PORT"
        
        print_success "Port updated to $NEW_PORT"
    else
        echo -e "${CYAN}Current forward configuration:${NC}"
        grep -A3 "^forward:" "$PAQET_CONFIG" | head -10
        echo ""
        
        read_ports "Enter new forward ports (comma-separated)" NEW_PORTS "$DEFAULT_FORWARD_PORTS"
        
        # Rebuild forward section
        local forward_config=""
        IFS=',' read -ra PORTS <<< "$NEW_PORTS"
        for port in "${PORTS[@]}"; do
            port=$(echo "$port" | tr -d ' ')
            forward_config="${forward_config}
  - listen: \"0.0.0.0:${port}\"
    target: \"127.0.0.1:${port}\"
    protocol: \"tcp\""
        done
        
        # Use awk to replace the forward section
        awk -v new_forward="forward:${forward_config}" '
            /^forward:/ { in_forward=1; print new_forward; next }
            in_forward && /^[a-z]/ { in_forward=0 }
            !in_forward { print }
        ' "$PAQET_CONFIG" > "${PAQET_CONFIG}.tmp"
        mv "${PAQET_CONFIG}.tmp" "$PAQET_CONFIG"
        
        print_success "Forward ports updated"
    fi
    
    echo ""
    read_confirm "Restart paqet service to apply changes?" restart_now "y"
    if [ "$restart_now" = true ]; then
        systemctl restart $PAQET_SERVICE
        print_success "Service restarted"
    fi
}

edit_secret_key() {
    echo ""
    local new_key=$(generate_secret_key)
    echo -e "${CYAN}Generated new key: $new_key${NC}"
    read_required "Enter new secret key (or use generated)" SECRET_KEY "$new_key"
    
    sed -i "s/key: \"[^\"]*\"/key: \"${SECRET_KEY}\"/" "$PAQET_CONFIG"
    print_success "Secret key updated"
    
    print_warning "Remember to update the key on the other server as well!"
    
    echo ""
    read_confirm "Restart paqet service to apply changes?" restart_now "y"
    if [ "$restart_now" = true ]; then
        systemctl restart $PAQET_SERVICE
        print_success "Service restarted"
    fi
}

edit_kcp_settings() {
    echo ""
    echo -e "${YELLOW}KCP Mode options:${NC}"
    echo -e "  ${CYAN}normal${NC}  - Balanced (default)"
    echo -e "  ${CYAN}fast${NC}    - Low latency"
    echo -e "  ${CYAN}fast2${NC}   - Lower latency"
    echo -e "  ${CYAN}fast3${NC}   - Aggressive, best for high latency"
    echo ""
    
    local current_mode=$(grep "mode:" "$PAQET_CONFIG" | awk '{print $2}' | tr -d '"')
    read_required "Enter KCP mode" KCP_MODE "$current_mode"
    
    local current_conn=$(grep "conn:" "$PAQET_CONFIG" | awk '{print $2}')
    read_required "Enter number of parallel connections (1-8)" KCP_CONN "$current_conn"
    
    sed -i "s/mode: \"[^\"]*\"/mode: \"${KCP_MODE}\"/" "$PAQET_CONFIG"
    sed -i "s/conn: [0-9]*/conn: ${KCP_CONN}/" "$PAQET_CONFIG"
    
    print_success "KCP settings updated"
    
    echo ""
    read_confirm "Restart paqet service to apply changes?" restart_now "y"
    if [ "$restart_now" = true ]; then
        systemctl restart $PAQET_SERVICE
        print_success "Service restarted"
    fi
}

edit_interface() {
    echo ""
    local current_iface=$(grep "interface:" "$PAQET_CONFIG" | awk '{print $2}' | tr -d '"')
    echo -e "Current interface: ${CYAN}$current_iface${NC}"
    echo ""
    echo -e "${YELLOW}Available interfaces:${NC}"
    ip -o link show | awk -F': ' '{print "  " $2}'
    echo ""
    
    read_required "Enter network interface" NEW_IFACE "$current_iface"
    
    local new_ip=$(get_local_ip "$NEW_IFACE")
    if [ -z "$new_ip" ]; then
        read_ip "Could not detect IP. Enter local IP for $NEW_IFACE" new_ip
    fi
    
    local new_mac=$(get_gateway_mac)
    if [ -z "$new_mac" ]; then
        read_mac "Enter gateway MAC address" new_mac
    fi
    
    sed -i "s/interface: \"[^\"]*\"/interface: \"${NEW_IFACE}\"/" "$PAQET_CONFIG"
    sed -i "s/router_mac: \"[^\"]*\"/router_mac: \"${new_mac}\"/" "$PAQET_CONFIG"
    # Update IP in addr field (keeping the port)
    sed -i "s|addr: \"[0-9.]*:|addr: \"${new_ip}:|" "$PAQET_CONFIG"
    
    print_success "Network interface updated"
    
    echo ""
    read_confirm "Restart paqet service to apply changes?" restart_now "y"
    if [ "$restart_now" = true ]; then
        systemctl restart $PAQET_SERVICE
        print_success "Service restarted"
    fi
}

edit_server_address() {
    echo ""
    local current_addr=$(grep -A1 "^server:" "$PAQET_CONFIG" | grep "addr:" | awk '{print $2}' | tr -d '"')
    local current_ip=$(echo "$current_addr" | cut -d':' -f1)
    local current_port=$(echo "$current_addr" | cut -d':' -f2)
    
    echo -e "Current Server B: ${CYAN}$current_addr${NC}"
    echo ""
    
    read_ip "Enter Server B IP address" NEW_SERVER_IP "$current_ip"
    read_port "Enter Server B paqet port" NEW_SERVER_PORT "$current_port"
    
    sed -i "s|addr: \"${current_addr}\"|addr: \"${NEW_SERVER_IP}:${NEW_SERVER_PORT}\"|" "$PAQET_CONFIG"
    
    print_success "Server B address updated to ${NEW_SERVER_IP}:${NEW_SERVER_PORT}"
    
    echo ""
    read_confirm "Restart paqet service to apply changes?" restart_now "y"
    if [ "$restart_now" = true ]; then
        systemctl restart $PAQET_SERVICE
        print_success "Service restarted"
    fi
}

#===============================================================================
# Connection Test Tool
#===============================================================================

test_connection() {
    print_banner
    echo -e "${YELLOW}Connection Test Tool${NC}"
    echo ""
    
    if [ ! -f "$PAQET_CONFIG" ]; then
        print_error "paqet is not configured on this server"
        print_info "Please run setup first"
        return 1
    fi
    
    local role=$(grep "^role:" "$PAQET_CONFIG" 2>/dev/null | awk '{print $2}' | tr -d '"')
    
    echo -e "Detected role: ${CYAN}$role${NC}"
    echo ""
    
    # Check if service is running
    print_step "Checking paqet service..."
    if systemctl is-active --quiet $PAQET_SERVICE 2>/dev/null; then
        print_success "paqet service is running"
    else
        print_error "paqet service is NOT running"
        echo ""
        read_confirm "Would you like to start it?" start_svc "y"
        if [ "$start_svc" = true ]; then
            systemctl start $PAQET_SERVICE
            sleep 2
            if systemctl is-active --quiet $PAQET_SERVICE; then
                print_success "Service started"
            else
                print_error "Failed to start service"
                echo -e "${YELLOW}Check logs:${NC} journalctl -u $PAQET_SERVICE -n 20"
                return 1
            fi
        else
            return 1
        fi
    fi
    
    echo ""
    
    if [ "$role" = "server" ]; then
        # Server B tests
        test_server_b
    else
        # Server A tests
        test_server_a
    fi
}

test_server_b() {
    echo -e "${GREEN}Running Server B (Abroad) tests...${NC}"
    echo ""
    
    local listen_port=$(grep -A1 "^listen:" "$PAQET_CONFIG" | grep "addr:" | sed 's/.*:\([0-9]*\)".*/\1/')
    
    # Test 1: Check if paqet is listening
    print_step "Test 1: Checking if paqet is listening on port $listen_port..."
    if ss -tuln | grep -q ":${listen_port} "; then
        print_success "paqet is listening on port $listen_port"
    else
        print_warning "paqet might be using raw sockets (not visible in ss)"
        print_info "This is normal for paqet"
    fi
    
    echo ""
    
    # Test 2: Check iptables rules
    print_step "Test 2: Checking iptables rules..."
    local raw_rules=$(iptables -t raw -L -n 2>/dev/null | grep -c "$listen_port" || echo "0")
    local mangle_rules=$(iptables -t mangle -L -n 2>/dev/null | grep -c "$listen_port" || echo "0")
    
    if [ "$raw_rules" -gt 0 ] && [ "$mangle_rules" -gt 0 ]; then
        print_success "iptables rules are configured"
    else
        print_warning "Some iptables rules may be missing"
        print_info "Run setup again to reconfigure"
    fi
    
    echo ""
    
    # Test 3: Check for recent connections in logs
    print_step "Test 3: Checking recent activity..."
    local recent_logs=$(journalctl -u $PAQET_SERVICE --since "5 minutes ago" 2>/dev/null | tail -5)
    if [ -n "$recent_logs" ]; then
        echo "$recent_logs"
    else
        print_info "No recent activity in logs"
    fi
    
    echo ""
    
    # Test 4: External connectivity check
    print_step "Test 4: Checking external connectivity..."
    if curl -s --max-time 5 ifconfig.me >/dev/null 2>&1; then
        local public_ip=$(curl -s --max-time 5 ifconfig.me 2>/dev/null)
        print_success "External connectivity OK (Public IP: $public_ip)"
    else
        print_warning "Cannot reach external services"
    fi
    
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Server B Checklist:${NC}"
    echo -e "  • Ensure port ${CYAN}$listen_port${NC} is open in cloud firewall"
    echo -e "  • Ensure V2Ray/X-UI listens on ${CYAN}0.0.0.0${NC}"
    echo -e "  • Share the secret key with Server A"
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
}

test_server_a() {
    echo -e "${GREEN}Running Server A (Iran/Entry Point) tests...${NC}"
    echo ""
    
    local server_addr=$(grep -A1 "^server:" "$PAQET_CONFIG" | grep "addr:" | awk '{print $2}' | tr -d '"')
    local server_ip=$(echo "$server_addr" | cut -d':' -f1)
    local server_port=$(echo "$server_addr" | cut -d':' -f2)
    
    echo -e "Target Server B: ${CYAN}$server_addr${NC}"
    echo ""
    
    # Test 1: Basic network connectivity
    print_step "Test 1: Basic network connectivity to Server B..."
    if ping -c 1 -W 3 "$server_ip" >/dev/null 2>&1; then
        print_success "Server B is reachable via ICMP"
    else
        print_warning "ICMP blocked (this may be normal)"
    fi
    
    echo ""
    
    # Test 2: TCP connectivity to paqet port
    # NOTE: paqet uses raw sockets, so standard TCP probes won't get a response
    # This is EXPECTED - paqet is designed to be invisible to normal TCP
    print_step "Test 2: TCP probe to Server B port $server_port..."
    print_info "Note: paqet uses raw sockets - standard TCP may not respond"
    
    local tcp_reachable=false
    if timeout 5 bash -c "echo >/dev/tcp/$server_ip/$server_port" 2>/dev/null; then
        tcp_reachable=true
    elif command -v nc >/dev/null 2>&1; then
        if nc -z -w 5 "$server_ip" "$server_port" 2>/dev/null; then
            tcp_reachable=true
        fi
    fi
    
    if [ "$tcp_reachable" = true ]; then
        print_success "Port $server_port responds to TCP (unusual for paqet)"
    else
        print_warning "No TCP response on port $server_port"
        print_info "This is NORMAL - paqet operates at raw socket level"
        print_info "The tunnel may still work. Run end-to-end test to verify."
    fi
    
    echo ""
    
    # Test 3: Check forwarded ports
    print_step "Test 3: Checking forwarded ports..."
    local forward_ports=$(grep -A10 "^forward:" "$PAQET_CONFIG" | grep "listen:" | sed 's/.*:\([0-9]*\)".*/\1/' | tr '\n' ' ')
    
    for port in $forward_ports; do
        if ss -tuln | grep -q ":${port} "; then
            print_success "Port $port is listening"
        else
            print_warning "Port $port may be using raw sockets"
        fi
    done
    
    echo ""
    
    # Test 4: Check recent tunnel activity
    print_step "Test 4: Checking tunnel activity..."
    local recent_logs=$(journalctl -u $PAQET_SERVICE --since "5 minutes ago" 2>/dev/null | grep -iE "connect|tunnel|forward" | tail -3)
    if [ -n "$recent_logs" ]; then
        echo "$recent_logs"
    else
        print_info "No recent tunnel activity"
    fi
    
    echo ""
    
    # Test 5: End-to-end test (if user wants)
    echo -e "${YELLOW}Would you like to run an end-to-end test?${NC}"
    echo -e "${CYAN}This will attempt to connect through the tunnel.${NC}"
    read_confirm "Run end-to-end test?" run_e2e "n"
    
    if [ "$run_e2e" = true ]; then
        echo ""
        local test_port=$(echo "$forward_ports" | awk '{print $1}')
        print_step "Attempting connection through tunnel on port $test_port..."
        
        if timeout 10 bash -c "echo >/dev/tcp/127.0.0.1/$test_port" 2>/dev/null; then
            print_success "Tunnel connection successful!"
        else
            print_error "Tunnel connection failed"
            print_info "Check logs: journalctl -u $PAQET_SERVICE -f"
        fi
    fi
    
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Server A Checklist:${NC}"
    echo -e "  • Verify secret key matches Server B"
    echo -e "  • Ensure Server B's cloud firewall allows port $server_port"
    echo -e "  • TCP probe failing is NORMAL (paqet uses raw sockets)"
    echo -e "  • Update V2Ray clients to use this server's IP"
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
}

#===============================================================================
# Auto-Updater
#===============================================================================

check_for_updates() {
    print_banner
    echo -e "${YELLOW}Checking for Updates${NC}"
    echo ""
    
    print_step "Current version: ${CYAN}$INSTALLER_VERSION${NC}"
    echo ""
    
    print_step "Fetching latest version from GitHub..."
    
    # Get latest version from GitHub
    local latest_version=""
    local release_info=""
    local raw_script=""
    
    # Method 1: Try GitHub releases API
    release_info=$(curl -s --max-time 10 "https://api.github.com/repos/${INSTALLER_REPO}/releases/latest" 2>/dev/null)
    if [ -n "$release_info" ]; then
        latest_version=$(echo "$release_info" | grep '"tag_name"' | sed -E 's/.*"v?([^"]+)".*/\1/')
    fi
    
    # Method 2: If no release found, fetch from raw main branch
    if [ -z "$latest_version" ]; then
        print_info "No releases found, checking main branch..."
        raw_script=$(curl -s --max-time 15 "https://raw.githubusercontent.com/${INSTALLER_REPO}/main/install.sh" 2>/dev/null)
        if [ -n "$raw_script" ]; then
            latest_version=$(echo "$raw_script" | grep 'INSTALLER_VERSION=' | head -1 | cut -d'"' -f2)
        fi
    fi
    
    if [ -z "$latest_version" ]; then
        print_error "Could not fetch version information"
        print_info "This may be due to network restrictions"
        echo ""
        echo -e "${YELLOW}Manual update:${NC}"
        echo -e "  ${CYAN}bash <(curl -fsSL https://raw.githubusercontent.com/${INSTALLER_REPO}/main/install.sh)${NC}"
        return 1
    fi
    
    print_info "Latest version: ${CYAN}$latest_version${NC}"
    echo ""
    
    # Compare versions (simple string comparison)
    if [ "$INSTALLER_VERSION" = "$latest_version" ]; then
        print_success "You are running the latest version!"
        return 0
    fi
    
    # Version is different (could be newer or older)
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}A new version is available!${NC}"
    echo -e "  Current: ${RED}$INSTALLER_VERSION${NC}"
    echo -e "  Latest:  ${GREEN}$latest_version${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    read_confirm "Would you like to update now?" do_update "y"
    
    if [ "$do_update" = true ]; then
        update_installer
    fi
}

update_installer() {
    print_step "Downloading latest installer..."
    
    local temp_script="/tmp/paqet_install_new.sh"
    local download_url="https://raw.githubusercontent.com/${INSTALLER_REPO}/main/install.sh"
    
    if curl -fsSL "$download_url" -o "$temp_script" 2>/dev/null; then
        chmod +x "$temp_script"
        
        # Verify the downloaded script
        if grep -q "INSTALLER_VERSION" "$temp_script"; then
            local new_version=$(grep '^INSTALLER_VERSION=' "$temp_script" | cut -d'"' -f2)
            print_success "Downloaded version: $new_version"
            
            # Backup current config if exists
            if [ -f "$PAQET_CONFIG" ]; then
                cp "$PAQET_CONFIG" "${PAQET_CONFIG}.backup"
                print_info "Configuration backed up to ${PAQET_CONFIG}.backup"
            fi
            
            echo ""
            print_step "Launching updated installer..."
            echo ""
            
            # Execute the new script
            exec bash "$temp_script"
        else
            print_error "Downloaded file doesn't appear to be valid"
            rm -f "$temp_script"
            return 1
        fi
    else
        print_error "Failed to download update"
        print_info "Network may be restricted. Try manual update:"
        echo -e "  ${CYAN}bash <(curl -fsSL $download_url)${NC}"
        return 1
    fi
}

#===============================================================================
# Quick Port Configuration Display
#===============================================================================

show_port_config() {
    echo ""
    echo -e "${MAGENTA}════════════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA}              Current Port Configuration                    ${NC}"
    echo -e "${MAGENTA}════════════════════════════════════════════════════════════${NC}"
    echo -e "  ${YELLOW}Default paqet port:${NC}     ${CYAN}$DEFAULT_PAQET_PORT${NC}"
    echo -e "  ${YELLOW}Default forward ports:${NC}  ${CYAN}$DEFAULT_FORWARD_PORTS${NC}"
    echo -e "  ${YELLOW}KCP mode:${NC}               ${CYAN}$DEFAULT_KCP_MODE${NC}"
    echo -e "  ${YELLOW}KCP connections:${NC}        ${CYAN}$DEFAULT_KCP_CONN${NC}"
    echo -e "${MAGENTA}════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}To change defaults, edit the script header configuration section.${NC}"
    echo ""
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
        echo -e "  ${GREEN}── Setup ──${NC}"
        echo -e "  ${CYAN}1)${NC} Setup Server B (Abroad - VPN server)"
        echo -e "  ${CYAN}2)${NC} Setup Server A (Iran - entry point)"
        echo ""
        echo -e "  ${GREEN}── Management ──${NC}"
        echo -e "  ${CYAN}3)${NC} Check Status"
        echo -e "  ${CYAN}4)${NC} View Configuration"
        echo -e "  ${CYAN}5)${NC} Edit Configuration"
        echo -e "  ${CYAN}6)${NC} Test Connection"
        echo ""
        echo -e "  ${GREEN}── Maintenance ──${NC}"
        echo -e "  ${CYAN}7)${NC} Check for Updates"
        echo -e "  ${CYAN}8)${NC} Show Port Defaults"
        echo -e "  ${CYAN}9)${NC} Uninstall"
        echo -e "  ${CYAN}0)${NC} Exit"
        echo ""
        read -p "Choice [0-9]: " choice < /dev/tty
        
        case $choice in
            1) install_dependencies; setup_server_b ;;
            2) run_iran_optimizations; install_dependencies; setup_server_a ;;
            3) check_status ;;
            4) view_config ;;
            5) edit_config ;;
            6) test_connection ;;
            7) check_for_updates ;;
            8) show_port_config ;;
            9) uninstall ;;
            0) exit 0 ;;
            *) print_error "Invalid choice" ;;
        esac
        
        echo ""
        echo -e "${YELLOW}Press Enter to continue...${NC}"
        read < /dev/tty
    done
}

main "$@"
