# paqet-tunnel

Easy installer for tunneling VPN traffic through a middle server using [paqet](https://github.com/hanselime/paqet) - a raw packet-level tunneling tool that bypasses network restrictions.

**Current Version:** v1.5.1

## Features

- **Interactive Setup** - Guided installation for both Iran and abroad servers
- **Input Validation** - Won't exit on invalid input, keeps asking until valid
- **Iran Network Optimization** - Optional DNS and apt mirror optimization for Iran servers
- **Configuration Editor** - Change ports, keys, KCP settings, and MTU without manual file editing
- **Connection Test Tool** - Built-in diagnostics to verify tunnel connectivity
- **Auto-Updater** - Check for and install updates from within the script
- **Smart Defaults** - Sensible defaults with easy customization

## Use Case

This tool is designed for users in **Iran** (or other restricted regions) who need to access VPN servers located **abroad**. Instead of connecting directly to your VPN server (which may be blocked or throttled), traffic is routed through a middle server using raw packet tunneling that evades detection.

## Overview

paqet uses raw TCP packet injection to create a tunnel that:
- Bypasses kernel-level connection tracking (conntrack)
- Uses KCP protocol for encrypted, reliable transport
- Is much harder to detect than SSH or VPN protocols
- Evades Deep Packet Inspection (DPI)

## Architecture

```
┌─────────────┐                              ┌─────────────┐
│  Clients    │                              │   Server B  │
│  (V2Ray)    │                              │  (ABROAD)   │
└──────┬──────┘                              │  VPN Server │
       │                                     │  e.g. USA   │
       │ Connect to                          └──────┬──────┘
       │ Server A IP                                │
       ▼                                            │ V2Ray/X-UI
┌──────────────┐      paqet tunnel           ┌──────▼──────┐
│   Server A   │◄───────────────────────────►│   paqet     │
│   (IRAN)     │     (KCP encrypted)         │   server    │
│ Entry Point  │                             │  port 8888  │
└──────────────┘                             └─────────────┘
```

**Servers:**
- **Server A (Iran)**: Entry point server located in Iran - clients connect here
- **Server B (Abroad)**: Your VPN server abroad (USA, Germany, etc.) running V2Ray/X-UI

**Traffic Flow:**
1. Client connects to Server A (Iran) on the V2Ray port
2. Server A tunnels traffic through paqet to Server B (Abroad)
3. Server B forwards to local V2Ray (`127.0.0.1:PORT`)
4. Response flows back through the tunnel

## Quick Start

```bash
# Run on both servers (as root)
bash <(curl -fsSL https://raw.githubusercontent.com/g3ntrix/paqet-tunnel/main/install.sh)
```

## Installation Steps

### Step 1: Setup Server B (Abroad - VPN Server)

```bash
ssh root@<SERVER_B_IP>
bash <(curl -fsSL https://raw.githubusercontent.com/g3ntrix/paqet-tunnel/main/install.sh)
```

1. Select option **1** (Setup Server B)
2. Confirm network settings (auto-detected)
3. Choose paqet port (default: `8888`)
4. Enter V2Ray port(s) (e.g., `443`)
5. **Save the generated secret key!**

### Step 2: Setup Server A (Iran - Entry Point)

```bash
ssh root@<SERVER_A_IP>
bash <(curl -fsSL https://raw.githubusercontent.com/g3ntrix/paqet-tunnel/main/install.sh)
```

> **Note:** If download is blocked in Iran, the installer will ask for a local file path. Download the paqet binary manually and provide the path.

1. Select option **2** (Setup Server A)
2. **Optional:** Run Iran network optimization (DNS + apt mirrors)
3. Enter Server B's IP address
4. Enter paqet port: `8888`
5. Enter the **secret key** from Step 1
6. Confirm network settings
7. Enter port(s) to forward (same as V2Ray ports)

#### Iran Network Optimization (Optional)

When setting up Server A, you'll be prompted to run optimization scripts:

```
════════════════════════════════════════════════════════════
          Iran Server Network Optimization                  
════════════════════════════════════════════════════════════

These scripts can help optimize your Iran server:
  1. DNS Finder - Find the best DNS servers for Iran
  2. Mirror Selector - Find the fastest apt repository mirror

Run network optimization scripts before installation? (Y/n):
```

This runs:
- [IranDNSFinder](https://github.com/alinezamifar/IranDNSFinder) - Finds and configures optimal DNS servers
- [DetectUbuntuMirror](https://github.com/alinezamifar/DetectUbuntuMirror) - Selects the fastest apt mirror (Ubuntu/Debian only)

These optimizations can significantly improve download speeds on Iran servers.

### Step 3: Update Client Config

```
# Before (direct to Server B abroad)
vless://uuid@<SERVER_B_IP>:443?type=tcp&...

# After (through Server A in Iran)
vless://uuid@<SERVER_A_IP>:443?type=tcp&...
```

Only change the IP address - everything else stays the same!

## ⚠️ Important: V2Ray Inbound Configuration

On **Server B (Abroad)**, your V2Ray/X-UI inbound **MUST** listen on `0.0.0.0` (all interfaces), not just the public IP or empty.

In X-UI Panel:
1. Go to **Inbounds** → Edit your inbound
2. Set **Listen IP** to: `0.0.0.0`
3. Save and restart X-UI

This is required because paqet forwards traffic to `127.0.0.1:PORT`, and V2Ray must accept connections on localhost.

## Manual Dependency Installation (Iran Servers)

If `apt update` gets stuck due to internet restrictions in Iran, install dependencies manually **before** running the installer:

```bash
# Skip apt update and install from cache
apt install -y --no-install-recommends libpcap-dev iptables curl

# Or install minimal required packages
apt install -y libpcap0.8 iptables curl

# Verify installation
dpkg -l | grep -E "libpcap|iptables|curl"
```

When running the installer, choose **'s'** to skip dependency installation when prompted.

## Performance Optimization

The default settings are conservative. For better speed or to fix EOF/MTU issues, you can tune KCP from the menu or manually:

### Via Menu (Recommended)

On **both servers**, run the installer and choose:

- **Option 5** → **Edit Configuration**
- Then **Option 3** → **KCP Settings**

You can adjust:
- **Mode**: `normal`, `fast`, `fast2`, `fast3`
- **Connections**: number of parallel KCP connections
- **MTU**: default `1350` (try `1280-1300` on problematic networks)

### Manual Tuning Example

Edit `/opt/paqet/config.yaml` on **both servers**:

```yaml
transport:
  protocol: "kcp"
  conn: 4                    # Multiple parallel connections
  kcp:
    mode: "fast3"            # Aggressive retransmission
    key: "YOUR_SECRET_KEY"
    mtu: 1350                # Lower for restrictive networks (1280–1400)
    snd_wnd: 2048            # Large send window
    rcv_wnd: 2048            # Large receive window
    data_shard: 10           # FEC error correction
    parity_shard: 3          # FEC redundancy
```

Then restart both services:
```bash
systemctl restart paqet
```

## Menu Options

The installer provides a full management interface:

```
── Setup ──
1) Setup Server B (Abroad - VPN server)
2) Setup Server A (Iran - entry point)

── Management ──
3) Check Status
4) View Configuration
5) Edit Configuration
6) Test Connection

── Maintenance ──
7) Check for Updates
8) Show Port Defaults
9) Uninstall
0) Exit
```

### Edit Configuration (Option 5)

Change settings without manually editing config files:
- **Ports** - Change paqet or forwarded ports
- **Secret Key** - Generate or set a new key
- **KCP Settings** - Adjust mode (normal/fast/fast2/fast3) and connections
- **Network Interface** - Change the network interface
- **Server B Address** - Update the abroad server IP/port (client only)

### Test Connection (Option 6)

Built-in diagnostics that automatically detect your server role and run appropriate tests:

**Server A (Iran) tests:**
- Service status check
- Network connectivity to Server B
- Forwarded ports verification
- Tunnel activity logs
- End-to-end tunnel test

**Server B (Abroad) tests:**
- Service status check
- Listening port verification
- iptables rules check
- Recent activity logs
- External connectivity

> **Note:** TCP probe tests may show "no response" even when the tunnel works. This is normal - paqet uses raw sockets and doesn't respond to standard TCP probes.

### Check for Updates (Option 7)

The installer can update itself:
- Checks GitHub for the latest version
- Compares with current version
- Downloads and launches the new version automatically
- Backs up existing configuration before updating

## Commands

```bash
# Check status
systemctl status paqet

# View logs
journalctl -u paqet -f

# Restart service
systemctl restart paqet

# View configuration
cat /opt/paqet/config.yaml

# Uninstall
# Run installer again and select option 9
```

## Requirements

- Linux server (Ubuntu, Debian, CentOS, etc.)
- Root access
- `libpcap-dev` (auto-installed)
- iptables

## How paqet Works

| Feature | Description |
|---------|-------------|
| **Raw Packets** | Injects TCP packets directly, bypassing OS networking |
| **Kernel Bypass** | Uses pcap library to bypass conntrack |
| **KCP Protocol** | Encrypted, reliable transport layer |
| **RST Blocking** | Drops kernel RST packets via iptables |
| **No Handshake** | No identifiable protocol signature |

## Troubleshooting

**Connection timeout:**
- Verify secret keys match exactly on both servers
- Check iptables rules: `iptables -t raw -L -n`
- Ensure cloud firewall allows the paqet port (8888)
- Make sure V2Ray inbound listens on `0.0.0.0`
- Run the **Test Connection** tool (option 6) for diagnostics

**Download blocked in Iran:**
- Run the **Iran Network Optimization** when prompted during Server A setup
- Download paqet manually from [releases](https://github.com/hanselime/paqet/releases)
- Installer will prompt for local file path

**Port already in use:**
- Installer will detect this and offer to kill the process

**Service not starting:**
- Check logs: `journalctl -u paqet -n 50`
- Verify config: `cat /opt/paqet/config.yaml`

**Slow speed:**
- Apply performance optimizations above
- Try increasing `conn` to 8 (use Edit Configuration, option 5)
- Check server CPU/bandwidth limits

**Clients can't connect:**
- Verify V2Ray inbound listens on `0.0.0.0`
- Verify Server A's firewall allows the forwarded ports
- Check both paqet services are running
- Use **Test Connection** (option 6) to diagnose

**TCP probe shows "no response":**
- This is **normal** for paqet - it uses raw sockets
- Run the end-to-end test in Test Connection to verify the tunnel works

## License

MIT License

## Credits

- [paqet](https://github.com/hanselime/paqet) - Raw packet tunneling library by hanselime
