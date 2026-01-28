<!-- SPDX-License-Identifier: MIT OR Apache-2.0 -->
# Contributing to vscode-tunnel-setup

Thank you for your interest in contributing!

## Code of Conduct

By participating in this project, you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md).

## Getting Started

### Prerequisites

- Bash 4.0+
- Docker (for integration tests)
- [bats-core](https://github.com/bats-core/bats-core) (for running tests)

### Setup

```bash
git clone https://github.com/XMV-Solutions-GmbH/vscode-tunnel-setup.git
cd vscode-tunnel-setup

# Install test dependencies (macOS)
brew install bats-core

# Run tests
make test
```

## Development Guidelines

### Code Style

- Use [ShellCheck](https://www.shellcheck.net/) for shell script linting
- Follow British English spelling conventions
- Use 4-space indentation in shell scripts

### SPDX Headers

Every source file must start with an SPDX header:

```bash
#!/usr/bin/env bash
# SPDX-License-Identifier: MIT OR Apache-2.0
```

For Markdown files:

```markdown
<!-- SPDX-License-Identifier: MIT OR Apache-2.0 -->
```

### Documentation

- All public scripts must have usage documentation
- Include examples where helpful
- Update the README.md for user-facing changes

### Testing

- Unit tests are mandatory for all new functionality
- Integration tests are required for new features
- Run `make test` before submitting a PR

```bash
# Run all tests
make test

# Run only unit tests (no Docker)
make test-unit

# Run integration tests
make test-integration
```

## Pull Request Process

1. **Fork** the repository
2. **Create a feature branch** from `main`
3. **Make your changes** with clear, atomic commits
4. **Run all checks** (lint, test)
5. **Open a Pull Request** with a clear description
6. **Wait for CI** to pass
7. **Address review feedback**

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```text
feat: add new feature
fix: resolve bug in X
docs: update README
chore: update dependencies
test: add unit tests for Y
ci: update GitHub Actions workflow
```

## Types of Contributions

- 🐛 Bug reports
- ✨ Feature requests
- 📝 Documentation improvements
- 🧪 Test coverage
- 🔧 Code improvements

## Questions?

Open an issue or start a discussion!
