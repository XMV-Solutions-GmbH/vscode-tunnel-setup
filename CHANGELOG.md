<!-- SPDX-License-Identifier: MIT OR Apache-2.0 -->
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Service-based authentication: Device code is now read from systemd journal instead of manual CLI execution
- Improved box formatting for dynamic content display
- Added `--export` mode to generate remote script for manual deployment
- Added `--export-script` mode to output the script generator function
- GitHub Release workflow with curl-pipe-bash installation support

### Fixed

- Box formatting no longer has misaligned borders with dynamic content

## [1.0.0] - 2026-01-28

### Added

- Initial release
- One-command VS Code Tunnel setup script (`setup-vscode-tunnel.sh`)
- Automatic architecture detection (x64, arm64, armhf)
- Automatic VS Code CLI download and installation
- Systemd service creation and management
- Idempotent operation (safe to re-run)
- Comprehensive test suite with bats-core
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

[Unreleased]: https://github.com/XMV-Solutions-GmbH/vscode-tunnel-setup/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/XMV-Solutions-GmbH/vscode-tunnel-setup/releases/tag/v1.0.0
