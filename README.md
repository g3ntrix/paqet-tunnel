# paqet-tunnel

Easy installer for tunneling VPN traffic through a middle server using [paqet](https://github.com/hanselime/paqet) - a raw packet-level tunneling tool that bypasses network restrictions.

**Current Version:** v1.9.0

## Changelog

### v1.9.0
- **Automatic Reset** - Option (a) for scheduled service restarts (configurable interval)
- Configurable interval: 1/3/6/12 hours, 1 day, or 7 days
- Enable/disable toggle; manual reset now available from the same menu

### v1.8.0
- **Multi-Tunnel Support** - Run multiple named tunnels on Server A, each connecting to a different Server B
- Each tunnel gets its own config file (`config-<name>.yaml`) and systemd service (`paqet-<name>`)
- New **Manage Tunnels** menu (option 6): add, remove, restart, stop, start individual tunnels
- Status check now shows all tunnels at once
- Edit/View/Test operations prompt for tunnel selection when multiple exist
- Server B setup remains unchanged (single instance)

### v1.7.0
- **Port Settings** - Under Edit Configuration (option 5): add, remove, or replace V2Ray/paqet ports without full reconfiguration
- View current port configuration and change paqet tunnel port on both server roles

### v1.6.0
- **Install as Command** - Option to install script as `paqet-tunnel` system command
- Run `paqet-tunnel` anytime without needing curl
- Update/remove command from menu

### v1.5.1
- **MTU Configuration** - Added MTU setting in KCP configuration
- Helps fix EOF errors on restrictive networks (try 1280-1300)

### v1.5.0
- **Iran Network Optimization** - DNS finder and apt mirror selector for Iran servers
- Improved version fetching with fallback to raw main branch

### v1.4.0
- **Enhanced Input Validation** - Won't exit on invalid input, keeps asking until valid
- New default configurations for better out-of-box experience
- Improved TCP connectivity test messaging for raw socket behavior

### v1.3.0
- Auto-check `/root/paqet` for local archives before downloading
- Skip option for dependency installation
- Manual install guide for restricted networks

### v1.0.0
- Initial release with Server A/B setup
- Configuration editor for ports, keys, KCP settings
- Connection test tool and auto-updater

## Features

- **Interactive Setup** - Guided installation for both Iran and abroad servers
- **Multi-Tunnel Support** - Connect one Server A to multiple Server Bs with named tunnels
- **Install as Command** - Run `paqet-tunnel` after installing
- **Port Settings Menu** - Add, remove, or change V2Ray ports without reconfiguring
- **Input Validation** - Won't exit on invalid input, keeps asking until valid
- **Iran Network Optimization** - Optional DNS and apt mirror optimization for Iran servers
- **Configuration Editor** - Change ports, keys, KCP settings, and MTU without manual file editing
- **Connection Test Tool** - Built-in diagnostics to verify tunnel connectivity
- **Auto-Updater** - Check for and install updates from within the script
- **Automatic Reset** - Scheduled service restart for reliability (configurable interval)
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

### Single Server B

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

### Multiple Server Bs

Server A can run multiple named tunnels, each connecting to a different Server B:

```
                                             ┌──────────────┐
                          paqet-usa          │  Server B1   │
                     ┌──────────────────────►│  (USA)       │
                     │   ports 443,8443      │  port 8888   │
┌─────────────┐      │                       └──────────────┘
│  Clients    │      │                       ┌──────────────┐
│  (V2Ray)    │──►┌──┴───────────┐  germany  │  Server B2   │
└─────────────┘   │   Server A   ├──────────►│  (Germany)   │
                  │   (IRAN)     │  port 2053 │  port 8888   │
                  └──┬───────────┘           └──────────────┘
                     │                       ┌──────────────┐
                     │  paqet-france         │  Server B3   │
                     └──────────────────────►│  (France)    │
                         port 2096           │  port 8888   │
                                             └──────────────┘
```

Each tunnel has its own config (`/opt/paqet/config-<name>.yaml`) and service (`paqet-<name>`).

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

### Install as Command (Optional)

After running the script, select option **i** to install `paqet-tunnel` as a system command:

```bash
# After installation, you can simply run:
paqet-tunnel
```

This installs the script to `/usr/local/bin/paqet-tunnel` so you can run it anytime without curl.

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
3. Enter a **tunnel name** (e.g., `usa`, `germany`)
4. Enter Server B's IP address
5. Enter paqet port: `8888`
6. Enter the **secret key** from Step 1
7. Confirm network settings
8. Enter port(s) to forward (same as V2Ray ports)

To add more tunnels, run setup again (option **2** or via **Manage Tunnels**) with a different name.

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

Edit the config file on **both servers** (Server B: `config.yaml`, Server A: `config-<name>.yaml`):

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

Then restart:

```bash
# Server B
systemctl restart paqet

# Server A (replace <name> with tunnel name)
systemctl restart paqet-<name>
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
6) Manage Tunnels (add/remove/restart)
7) Test Connection

── Maintenance ──
8) Check for Updates
9) Show Port Defaults
u) Uninstall paqet

── Script ──
i) Install as 'paqet-tunnel' command
r) Remove paqet-tunnel command
0) Exit
```

### Manage Tunnels (Option 6)

Add, remove, and control individual tunnels on Server A:

- **Add new tunnel** - Runs Server A setup with a new tunnel name
- **Remove a tunnel** - Stops service and removes config for a selected tunnel
- **Restart/Stop/Start** - Control individual tunnel services

### Edit Configuration (Option 5)

Change settings without manually editing config files. If multiple tunnels exist, you'll be asked which one to edit:

- **Port Settings** - Add, remove, or change V2Ray/paqet ports (see below)
- **Secret Key** - Generate or set a new key
- **KCP Settings** - Adjust mode (normal/fast/fast2/fast3), connections, and MTU
- **Network Interface** - Change the network interface
- **Server B Address** - Update the abroad server IP/port (client only)

**Port Settings** (first option in Edit Configuration):

**For Server A (Iran/Client):**
- View current V2Ray forward ports
- Change paqet tunnel port (connection to Server B)
- Add new V2Ray forward port(s)
- Remove individual V2Ray forward port
- Replace all V2Ray forward ports

**For Server B (Abroad/Server):**
- View current paqet tunnel port
- Change paqet tunnel port

### Test Connection (Option 7)

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

### Check for Updates (Option 8)

The installer can update itself:

- Checks GitHub for the latest version
- Compares with current version
- Downloads and launches the new version automatically
- Backs up existing configuration before updating

## Commands

```bash
# Check status of a tunnel (replace <name> with tunnel name, e.g., usa)
systemctl status paqet-<name>

# View logs
journalctl -u paqet-<name> -f

# Restart a tunnel
systemctl restart paqet-<name>

# View configuration
cat /opt/paqet/config-<name>.yaml

# For Server B (single instance, no name needed)
systemctl status paqet
cat /opt/paqet/config.yaml

# Uninstall
# Run installer again and select option 'u'
```

## Requirements

- Linux server (Ubuntu, Debian, CentOS, etc.)
- Root access
- `libpcap-dev` (auto-installed)
- iptables

## How paqet Works


| Feature           | Description                                           |
| ----------------- | ----------------------------------------------------- |
| **Raw Packets**   | Injects TCP packets directly, bypassing OS networking |
| **Kernel Bypass** | Uses pcap library to bypass conntrack                 |
| **KCP Protocol**  | Encrypted, reliable transport layer                   |
| **RST Blocking**  | Drops kernel RST packets via iptables                 |
| **No Handshake**  | No identifiable protocol signature                    |


## Troubleshooting

**Connection timeout:**

- Verify secret keys match exactly on both servers
- Check iptables rules: `iptables -t raw -L -n`
- Ensure cloud firewall allows the paqet port (8888)
- Make sure V2Ray inbound listens on `0.0.0.0`
- Run the **Test Connection** tool (option 7) for diagnostics

**Download blocked in Iran:**

- Run the **Iran Network Optimization** when prompted during Server A setup
- Download paqet manually from [releases](https://github.com/hanselime/paqet/releases)
- Installer will prompt for local file path

**Port already in use:**

- Installer will detect this and offer to kill the process

**Service not starting:**

- Check logs: `journalctl -u paqet-<name> -n 50`
- Verify config: `cat /opt/paqet/config-<name>.yaml`

**Slow speed:**

- Apply performance optimizations above
- Try increasing `conn` to 8 (use Edit Configuration, option 5)
- Check server CPU/bandwidth limits

**Clients can't connect:**

- Verify V2Ray inbound listens on `0.0.0.0`
- Verify Server A's firewall allows the forwarded ports
- Check both paqet services are running
- Use **Test Connection** (option 7) to diagnose

**TCP probe shows "no response":**

- This is **normal** for paqet - it uses raw sockets
- Run the end-to-end test in Test Connection to verify the tunnel works

## License

MIT License

## Credits

- [paqet](https://github.com/hanselime/paqet) - Raw packet tunneling library by hanselime

