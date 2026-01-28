<!-- SPDX-License-Identifier: MIT OR Apache-2.0 -->
# Test Concept for VS Code Tunnel Setup Script

## Overview

Comprehensive test harness using bats-core with Docker-based integration testing.

## Test Structure

```text
tests/
├── unit/
│   └── argument_parsing.bats
├── integration/
│   └── remote_script.bats
├── e2e/
│   └── full_setup.bats
├── fixtures/
│   ├── Dockerfile.mock-server
│   ├── docker-compose.test.yml
│   ├── docker-entrypoint.sh
│   ├── mock_code_cli.sh
│   └── mock_systemctl.sh
├── test_helper.bash
└── run_tests.sh
```

## Todo

### Unit Tests (`tests/unit/argument_parsing.bats`)

| Status | Test Case | Description |
| ------ | --------- | ----------- |
| 🟢 | `help_flag_shows_usage` | `-h` displays help text and exits 0 |
| 🟢 | `no_args_shows_help` | No arguments displays help |
| 🟢 | `ip_only_prompts_for_name` | IP without `-n` triggers prompt |
| 🟢 | `custom_user_flag` | `-u admin` sets SSH_USER |
| 🟢 | `machine_name_flag` | `-n my-server` sets MACHINE_NAME |
| 🟢 | `all_flags_combined` | All flags parsed correctly |
| 🟢 | `invalid_flag_shows_help` | Unknown flag shows help |
| 🟢 | `empty_machine_name_error` | Empty name after prompt exits 1 |
| 🟢 | `default_user_is_root` | Default SSH_USER is root when -u not specified |
| 🟢 | `ip_address_captured_correctly` | Various IP formats work |
| 🟢 | `hostname_as_server` | Hostname works as server address |
| 🟢 | `machine_name_with_special_chars` | Machine name with hyphens and numbers |
| 🟢 | `flags_order_independent` | Flags can be in any order |
| 🟢 | `only_flag_no_ip_shows_error` | Flag without IP shows error |
| 🟢 | `interactive_name_input` | Name provided via stdin works |

### Integration Tests (`tests/integration/remote_script.bats`)

| Status | Test Case | Description |
| ------ | --------- | ----------- |
| 🟢 | `arch_detection_x64` | Detects x86_64 → x64 |
| 🟢 | `arch_detection_arm64` | Detects aarch64 → arm64 |
| 🟢 | `arch_detection_armhf` | Detects armv7l → armhf |
| 🟢 | `arch_unsupported_error` | Unknown arch exits 1 |
| 🟢 | `cli_install_idempotent` | Skip install if exists |
| 🟢 | `cli_install_needed` | Detects missing CLI |
| 🟢 | `cli_install_curl` | Downloads via curl |
| 🟢 | `cli_install_wget` | Downloads via wget fallback |
| 🟢 | `cli_install_no_downloader` | Error if no curl/wget |
| 🟢 | `service_create_new` | Creates systemd service |
| 🟢 | `service_skip_existing` | Skips if name matches |
| 🟢 | `service_update_name` | Updates if name differs |
| 🟢 | `service_file_content_valid` | Service file has correct structure |
| 🟢 | `service_uses_correct_binary_path` | ExecStart points to /usr/local/bin/code |
| 🟢 | `service_accepts_licence_terms` | Service includes licence acceptance flag |
| 🟢 | `download_url_x64` | Correct URL for x64 architecture |
| 🟢 | `download_url_arm64` | Correct URL for arm64 architecture |
| 🟢 | `download_url_armhf` | Correct URL for armhf architecture |

### E2E Tests (`tests/e2e/full_setup.bats`)

| Status | Test Case | Description |
| ------ | --------- | ----------- |
| 🟢 | `fresh_install_complete` | Full flow on clean system |
| 🟢 | `rerun_idempotent` | Second run changes nothing |
| 🟢 | `name_change_updates` | Changing name updates service |
| 🟢 | `service_survives_reboot` | Service enabled correctly |
| 🟢 | `error_handling_ssh_failure` | Handles SSH connection failure gracefully |
| 🟢 | `full_workflow_simulation` | Complete workflow without actual network |

### Fixtures

| Status | File | Description |
| ------ | ---- | ----------- |
| 🟢 | `Dockerfile.mock-server` | Alpine + SSH for testing |
| 🟢 | `mock_code_cli.sh` | Fake VS Code CLI that skips auth |
| 🟢 | `mock_systemctl.sh` | Mock systemctl for Alpine |
| 🟢 | `docker-entrypoint.sh` | Container initialisation script |
| 🟢 | `docker-compose.test.yml` | Orchestrate test containers |

### Infrastructure

| Status | Task | Description |
| ------ | ---- | ----------- |
| 🟢 | `test_helper.bash` | Common functions, setup/teardown |
| 🟢 | `run_tests.sh` | Main test runner script |
| 🟢 | `.github/workflows/test.yml` | CI pipeline for tests |
| 🟢 | `Makefile` | `make test` target |

### Manual / Real Integration Tests (`tests/manual/`)

| Status | Test Case | Description |
| ------ | --------- | ----------- |
| 🟢 | `real_tunnel_test.sh` | Creates REAL tunnel with GitHub auth |

#### Real Tunnel Test Features

- Downloads actual VS Code CLI from Microsoft
- Starts a real tunnel (requires GitHub Device Code auth)
- Verifies tunnel is accessible via vscode.dev
- Supports `--keep` flag to leave tunnel running
- Automatic cleanup on exit

## Dependencies

```bash
# Install bats-core
brew install bats-core  # macOS
# or
git clone https://github.com/bats-core/bats-core.git
cd bats-core && ./install.sh /usr/local

# Docker required for integration/E2E tests
```

## Running Tests

```bash
# All tests
./tests/run_tests.sh

# Unit only (no Docker needed)
bats tests/unit/

# Integration (requires Docker)
bats tests/integration/

# E2E (requires Docker)
bats tests/e2e/
```

## Mock Server Requirements

The Docker mock server must:

- Run Alpine Linux (matches CLI download target)
- Have SSH enabled with known credentials
- Support systemd or mock systemctl
- Have curl or wget installed
- Accept the mock VS Code CLI

## Notes

- Unit tests can run without Docker
- Integration/E2E tests spin up Docker containers
- Mock CLI skips GitHub authentication flow
- Tests must be idempotent and isolated
