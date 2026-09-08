# paqet-tunnel

Easy installer for tunneling VPN traffic through a middle server using [paqet](https://github.com/hanselime/paqet) — raw packet-level tunneling that bypasses network restrictions.

**Version:** v2.2.0 · built for paqet **v1.0.0-alpha.20**

## How it works

Clients connect to **Server A** (the Iran entry point), which tunnels traffic over an encrypted paqet/KCP link to **Server B** (abroad), where your V2Ray/X-UI runs. You only change the IP in your VPN client from Server B to Server A — nothing else.

```
Client ──▶ Server A (Iran) ══ paqet tunnel ══▶ Server B (abroad) ──▶ V2Ray
```

## Install

Run on **both** servers (as root):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/g3ntrix/paqet-tunnel/main/install.sh)
```

If you need a non-standard install directory on one server, prefix the command with `PAQET_DIR=/your/path`. For example, the current abroad deployment can be recreated under `/opt/paqet-komar`.

The first run is a guided wizard: it asks whether this machine is the abroad server or the Iran server, auto-detects the network, and walks you through the rest.

## Setup (two steps)

**1. Server B (abroad)** — choose **Abroad server (B)**:
- Confirm the detected network, pick the paqet port (default `8888`), enter your V2Ray port(s).
- Copy the **Connection String** it prints at the end (`paqet://…`).

**2. Server A (Iran)** — choose **Iran entry server (A)**:
- Give the tunnel a name, then **paste the Connection String** — it fills in the IP, port, key, ports, **and the paqet version** automatically.
- Choose a mode: **Port forwarding** (V2Ray/X-UI, the default) or **SOCKS5 proxy** (a general-purpose proxy that exits via Server B).
- A health check confirms the tunnel is live.

Then point your VPN client at **Server A's IP** instead of Server B's.

> To reach more abroad servers, run Server A setup again with a different tunnel name.

## Reliable SSH relay (easy setup and IP changes)

Some providers filter the raw packets paqet needs. The installer now includes a persistent encrypted TCP relay for that situation. It preserves the original VLESS UUID, port, transport, and client options; clients only replace the Iran IP.

Run the installer with **Reliable SSH relay** (`s` in the menu), or use the direct commands below.

### First-time pairing

1. On the **abroad VPS**, run `paqet-tunnel --relay-abroad`. Confirm its public IP, SSH user, and Xray/VLESS port (default `27111`). Copy the printed `relay://` code.
2. On the **Iran VPS**, run `paqet-tunnel --relay-iran`. Paste the `relay://` code and confirm the public client port. Copy the printed `relay-key://` code.
3. Back on the **abroad VPS**, run `paqet-tunnel --relay-authorize` and paste the `relay-key://` code.

The Iran service keeps retrying while you complete step 3, then connects automatically. The installer creates a dedicated key whose authorization permits forwarding only to the selected local Xray port; it cannot open a shell.

If you run directly from GitHub instead of installing the command, append the same flags to the install command, for example:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/g3ntrix/paqet-tunnel/main/install.sh) --relay-abroad
```

### When only the abroad IP changes

On the Iran VPS run:

```bash
paqet-tunnel --relay-update-ip
```

Enter the new IP. The installer verifies that its SSH host key is the same trusted server before changing the pinned host entry and systemd service. Nothing changes on clients.

### When the Iran VPS is replaced

Repeat the three pairing steps on the new Iran VPS. Client UUIDs and options remain unchanged; replace only the old Iran IP in their URLs. Check at any time with:

```bash
paqet-tunnel --relay-status
```

## Paqet-only recovery after an abroad IP change

Use this only for raw paqet deployments. Reliable SSH relay users should use `--relay-update-ip` above.

**Server B reset**
- Stop and remove any stale tunnel service, including unrelated backhaul units such as `backhaul-kharej8888.service`.
- Reinstall Server B first, using the current abroad IP and port `8888`.
- If you want the existing service name to stay `paqet-komar.service`, run the installer with `PAQET_DIR=/opt/paqet-komar` and use `komar` as the Server B instance name.
- Verify X-UI/V2Ray still listens on `0.0.0.0:443` with the same UUID that your VLESS client uses.

**Server A reset**
- Remove the old `paqet-komar.service` and its config, then reinstall Server A from scratch.
- Keep the client link unchanged; only the Server B IP behind the tunnel should change.
- Confirm the tunnel targets the new Server B IP on port `8888`, uses the same shared KCP key, and stays on `v1.0.0-alpha.20`.

**After reinstall**
- Test the tunnel from Server A before reconnecting clients.
- If the tunnel connects but clients still time out, re-check the Oracle security list / NSG for port `8888` and the local firewall rules on both servers.

### Version locking (important for alpha.20+)

paqet's raw binary protocol is **version-locked**: Server A and Server B must run the **exact same paqet version** or the tunnel silently fails. The installer handles this for you — Server B records its version in the Connection String, and Server A installs the matching binary automatically. All tunnels on one Server A share a single binary, so every Server B must run the same version. To track upstream releases instead of the pinned default, run with `PAQET_VERSION=latest bash install.sh`.

## ⚠️ Required: V2Ray must listen on 0.0.0.0

On **Server B**, set your V2Ray/X-UI inbound **Listen IP** to `0.0.0.0` (not the public IP, not empty). paqet delivers traffic to `127.0.0.1:PORT`, so V2Ray must accept localhost connections.

## Handy menu options

- **s** — Reliable SSH relay (pair servers, update abroad IP, status)
- **c** — Health check (verify the tunnel end-to-end)
- **k** — Show the Connection String again (Server B)
- **3** Status · **5** Edit config · **6** Manage tunnels · **u** Uninstall
- **i** — Install as the `paqet-tunnel` command (then just run `paqet-tunnel`)

## Commands

```bash
# Server B
systemctl status paqet
journalctl -u paqet -f

# Server A (per tunnel — <name> is your tunnel name)
systemctl status paqet-<name>
journalctl -u paqet-<name> -f
```

## Troubleshooting

- **`connection lost, retrying` / health check fails** — on Server A, the paqet port must be Server B's **tunnel port** (e.g. `8888`), not the V2Ray port. Re-run setup, or paste the Connection String so it's filled in automatically.
- **Clients can't connect** — confirm V2Ray listens on `0.0.0.0`, and the cloud firewall allows the paqet port on Server B.
- **A renamed Server B instance is missing** — re-run Server B setup and give it the same instance name you used before, such as `komar`.
- **Download blocked in Iran** — grab the paqet binary from [releases](https://github.com/hanselime/paqet/releases) and give the installer the local file path when prompted.
- **High latency** — usually the underlying Iran↔abroad route. Compare with a direct `ping` between the two servers; the tunnel can't go faster than that baseline.

## Requirements

Linux (Ubuntu / Debian / CentOS), root access, `libpcap` and `iptables` (auto-installed).

## Credits & License

Built on [paqet](https://github.com/hanselime/paqet) by hanselime. MIT License.
