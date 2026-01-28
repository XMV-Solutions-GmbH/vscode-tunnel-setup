<!-- SPDX-License-Identifier: MIT OR Apache-2.0 -->
# vscode-tunnel-setup

[![CI](https://github.com/XMV-Solutions-GmbH/vscode-tunnel-setup/actions/workflows/test.yml/badge.svg)](https://github.com/XMV-Solutions-GmbH/vscode-tunnel-setup/actions/workflows/test.yml)
[![License](https://img.shields.io/badge/license-MIT%2FApache--2.0-blue.svg)](LICENSE)
[![GitHub release](https://img.shields.io/github/v/release/XMV-Solutions-GmbH/vscode-tunnel-setup)](https://github.com/XMV-Solutions-GmbH/vscode-tunnel-setup/releases)
[![Coverage](https://img.shields.io/badge/coverage-85%25-green.svg)](tests/)
[![Contributions Welcome](https://img.shields.io/badge/contributions-welcome-brightgreen.svg)](CONTRIBUTING.md)

**One-command VS Code Tunnel setup for remote servers.**

Installs the VS Code CLI, configures a systemd service, and enables persistent remote development via [vscode.dev](https://vscode.dev) or VS Code Desktop — all with a single SSH command.

---

## Features

- ✅ **One command** — Run once, develop forever
- ✅ **Automatic architecture detection** — x64, arm64, armhf
- ✅ **Systemd service** — Survives reboots, auto-restarts on failure
- ✅ **Idempotent** — Safe to re-run, only changes what's needed
- ✅ **No dependencies** — Just bash, curl/wget, and systemd

## Non-Goals

- ❌ Windows support (use [official installer](https://code.visualstudio.com/docs/remote/tunnels))
- ❌ Non-systemd init systems

---

## Quick Start

```bash
# Basic usage
./setup-vscode-tunnel.sh 192.168.1.100 -n my-server

# With custom SSH user
./setup-vscode-tunnel.sh 192.168.1.100 -u admin -n my-server

# Show help
./setup-vscode-tunnel.sh -h
```

### What happens

1. 🔗 Connects to your server via SSH
2. 📦 Downloads the official VS Code CLI from Microsoft
3. 🔧 Creates a systemd service (`code-tunnel.service`)
4. 🔐 Prompts for GitHub authentication (Device Code flow)
5. 🚀 Starts the tunnel service

### Connect

After setup, connect via:

- **Browser**: `https://vscode.dev/tunnel/my-server`
- **VS Code Desktop**: Remote Explorer → Tunnels → `my-server`

---

## Installation

### Option 1: One-liner (recommended)

```bash
curl -fsSL https://github.com/XMV-Solutions-GmbH/vscode-tunnel-setup/releases/latest/download/setup-vscode-tunnel.sh | bash -s -- <server-ip> -n <tunnel-name>
```

### Option 2: Download from latest release

```bash
curl -fsSL https://github.com/XMV-Solutions-GmbH/vscode-tunnel-setup/releases/latest/download/setup-vscode-tunnel.sh -o setup-vscode-tunnel.sh
chmod +x setup-vscode-tunnel.sh
./setup-vscode-tunnel.sh <server-ip> -n <tunnel-name>
```

### Option 3: Clone the repository

```bash
git clone https://github.com/XMV-Solutions-GmbH/vscode-tunnel-setup.git
cd vscode-tunnel-setup
./setup-vscode-tunnel.sh <server-ip> -n <tunnel-name>
```

---

## Usage

```text
Usage: setup-vscode-tunnel.sh <server-ip> [-u <username>] [-n <machine-name>]

Options:
  <server-ip>       IP address or hostname of the server (required)
  -u <username>     SSH username (default: root)
  -n <machine-name> Name for the VS Code Tunnel instance
  -h                Display help message

Examples:
  ./setup-vscode-tunnel.sh 192.168.1.100
  ./setup-vscode-tunnel.sh 192.168.1.100 -u admin
  ./setup-vscode-tunnel.sh 192.168.1.100 -u admin -n my-server
```

---

## Requirements

### Local machine (where you run the script)

- Bash
- SSH client

### Remote server (target)

- Linux with systemd
- curl or wget
- Internet access (to download VS Code CLI and connect to tunnel service)

### Tested on

- Ubuntu 20.04, 22.04, 24.04
- Debian 11, 12
- Raspberry Pi OS
- Alpine Linux (with systemd)

---

## Managing the Service

On the remote server:

```bash
# Check status
sudo systemctl status code-tunnel

# View logs
sudo journalctl -u code-tunnel -f

# Restart service
sudo systemctl restart code-tunnel

# Stop service
sudo systemctl stop code-tunnel

# Disable auto-start
sudo systemctl disable code-tunnel
```

---

## Testing

This project includes a comprehensive test suite:

```bash
# Run all tests
make test

# Run only unit tests (no Docker required)
make test-unit

# Run integration tests (requires Docker)
make test-integration

# Run real tunnel test (interactive, requires GitHub auth)
make test-real
```

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Security

See [SECURITY.md](SECURITY.md) for our security policy.

---

## Licence

Licensed under either of:

- Apache Licence, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE) or <http://www.apache.org/licenses/LICENSE-2.0>)
- MIT licence ([LICENSE-MIT](LICENSE-MIT) or <http://opensource.org/licenses/MIT>)

at your option.

---

## Disclaimer

This project is **NOT** affiliated with Microsoft or Visual Studio Code.

The VS Code CLI is downloaded from official Microsoft servers. This script merely automates the setup process.

Provided AS-IS without warranty. Use at your own risk.
