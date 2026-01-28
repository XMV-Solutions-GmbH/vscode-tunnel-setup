<!-- SPDX-License-Identifier: MIT OR Apache-2.0 -->
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-01-28

### Added

- **Auto-user creation**: Script now creates users automatically if they don't exist
  - Copies SSH keys from root to new user
  - Adds user to sudo group
  - Interactive password prompt for new users
- **SSH options**: New flags for SSH configuration
  - `-p <port>` — Custom SSH port
  - `-i <keyfile>` — SSH identity file
  - `-f` — Force host key acceptance (bypass verification)
- **Auto-browser & clipboard**: Device code automatically copied to clipboard and browser opens
- **Root warning**: Script now warns when running as root and suggests dedicated user (default: `vscode`)
- **Host key detection**: Detects host key verification issues and suggests `-f` flag
- **Coverage badge**: 85% test coverage badge in README
- **Contributions welcome badge**: Added to README

### Changed

- Service-based authentication: Device code is now read from systemd journal instead of manual CLI execution
- Improved box formatting for dynamic content display (removed borders for symmetry)
- Device code box now shows clipboard/browser status hints

### Fixed

- Box formatting no longer has misaligned borders with dynamic content
- Linux username validation (rejects invalid characters like dots)

## [0.1.0] - 2026-01-28

### Added

- Initial release
- One-command VS Code Tunnel setup script (`setup-vscode-tunnel.sh`)
- Automatic architecture detection (x64, arm64, armhf)
- Automatic VS Code CLI download and installation
- Systemd service creation and management
- Idempotent operation (safe to re-run)
- `--export` mode to generate remote script for manual deployment
- `--export-script` mode to output the script generator function
- GitHub Release workflow with curl-pipe-bash installation support
- Comprehensive test suite with bats-core (39 tests)
  - Unit tests for argument parsing
  - Integration tests for remote script logic
  - E2E tests with Docker
- Docker-based real integration tests
- Manual tunnel verification tests
- Full OSS documentation (LICENSE, CONTRIBUTING, CODE_OF_CONDUCT, SECURITY)

### Security

- Downloads only from official Microsoft VS Code servers
- Uses HTTPS for all downloads
- Service runs with systemd isolation

[Unreleased]: https://github.com/XMV-Solutions-GmbH/vscode-tunnel-setup/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/XMV-Solutions-GmbH/vscode-tunnel-setup/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/XMV-Solutions-GmbH/vscode-tunnel-setup/releases/tag/v0.1.0
