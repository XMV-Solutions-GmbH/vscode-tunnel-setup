<!-- SPDX-License-Identifier: MIT OR Apache-2.0 -->
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.5.0] - 2026-05-11

### Added

- **Idempotent tunnel setup**: running the script with the same name/user on a host that already has a working service shows status only — no surprises, no re-registration. Interactive prompt when the existing config differs, asking before overwriting. `sudo` credentials cached once instead of repeated password prompts. Replaces the blocking `code tunnel unregister` call with direct state-file cleanup. ([#17](https://github.com/XMV-Solutions-GmbH/vscode-tunnel-setup/pull/17))
- **`SCRIPT_VERSION` displayed in the script header** + new `VERSION` file as the canonical source of truth for release tooling. ([#17](https://github.com/XMV-Solutions-GmbH/vscode-tunnel-setup/pull/17))
- **Release-deploy script** that drives the protected-`main` release flow: create a `release/vX.Y.Z` branch, open a PR via `gh`, wait for CI to go green, squash-merge, then tag the merged commit on `main` (triggers the GitHub Release workflow). ([#17](https://github.com/XMV-Solutions-GmbH/vscode-tunnel-setup/pull/17), [#18](https://github.com/XMV-Solutions-GmbH/vscode-tunnel-setup/pull/18), [#19](https://github.com/XMV-Solutions-GmbH/vscode-tunnel-setup/pull/19))

### Fixed

- **Release pipeline now runs unit tests.** Previously `bats-core` wasn't pre-installed on `ubuntu-latest`, so the release workflow silently skipped tests and printed a skip message. The workflow now installs `bats-core` explicitly (matching the CI workflow) and runs tests via the `run_tests.sh` harness. (commit `917763c`)
- **Release-deploy script no longer needs auto-merge enabled on the repo.** Switched from `gh pr merge --auto` to polling CI then `gh pr merge --squash` once green. Release branch is cleaned up on CI failure. ([#19](https://github.com/XMV-Solutions-GmbH/vscode-tunnel-setup/pull/19))

### Dependencies

- Bump `actions/checkout` from 4 to 6, `softprops/action-gh-release` from 1 to 3, `actions/upload-artifact` (all in the `actions` group) — auto-merged via Dependabot. ([#21](https://github.com/XMV-Solutions-GmbH/vscode-tunnel-setup/pull/21))
- Bump `ubuntu` base image from 24.04 to 26.04 in `/tests/docker-integration` — auto-merged via Dependabot. ([#22](https://github.com/XMV-Solutions-GmbH/vscode-tunnel-setup/pull/22))
- Bump `alpine` base image from 3.19 to 3.23 in `/tests/fixtures` — auto-merged via Dependabot. ([#4](https://github.com/XMV-Solutions-GmbH/vscode-tunnel-setup/pull/4))

## [0.4.0] - 2026-03-08

> CHANGELOG entry added retroactively in v0.5.0 — the v0.4.0 release shipped without a `CHANGELOG.md` block, but the tag exists and the feature below is what was published.

### Added

- **Optional full server update before tunnel setup.** New flag enabling a pre-tunnel-install host upgrade (apt-get update/upgrade/autoremove) on the SSH target before the VS Code tunnel binary is fetched. Useful for first-touch provisioning on a stale image. ([#15](https://github.com/XMV-Solutions-GmbH/vscode-tunnel-setup/pull/15))

## [0.3.0] - 2026-03-06

### Changed

- **Strict tunnel name validation**: Tunnel names now follow much stricter rules
  - Only lowercase letters (a-z), digits (0-9), hyphen (-), underscore (_)
  - Must start with a lowercase letter
  - Must end with a lowercase letter or digit
  - No consecutive special characters (e.g. `--`, `__`, `-_`, `_-`)
  - Length restricted to 2-20 characters (previously 1-64)
  - Uppercase letters are no longer accepted
- **Expanded test coverage**: 28 tunnel name validation tests (previously 11)

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

[Unreleased]: https://github.com/XMV-Solutions-GmbH/vscode-tunnel-setup/compare/v0.5.0...HEAD
[0.5.0]: https://github.com/XMV-Solutions-GmbH/vscode-tunnel-setup/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/XMV-Solutions-GmbH/vscode-tunnel-setup/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/XMV-Solutions-GmbH/vscode-tunnel-setup/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/XMV-Solutions-GmbH/vscode-tunnel-setup/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/XMV-Solutions-GmbH/vscode-tunnel-setup/releases/tag/v0.1.0
