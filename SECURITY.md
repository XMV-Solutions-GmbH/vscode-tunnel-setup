<!-- SPDX-License-Identifier: MIT OR Apache-2.0 -->
# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.x.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

If you discover a security vulnerability, please do **not** open a public issue.

### How to Report

1. **Email**: Send details to **oss@xmv.de**
2. **Subject**: `[SECURITY] vscode-tunnel-setup: <brief description>`
3. **Include**:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

### What to Expect

- **Acknowledgement**: Within 48 hours
- **Initial assessment**: Within 7 days
- **Resolution timeline**: Depends on severity, typically 30-90 days

### Disclosure Policy

- We follow [responsible disclosure](https://en.wikipedia.org/wiki/Responsible_disclosure)
- We will coordinate with you on disclosure timing
- Credit will be given in the security advisory (unless you prefer anonymity)

## Security Considerations

This script:

- Executes commands on remote servers via SSH
- Downloads binaries from Microsoft's official VS Code servers
- Creates systemd services running as root
- Stores GitHub authentication tokens on the remote server

### Best Practices

- Only run this script on servers you trust
- Use SSH key authentication instead of passwords
- Review the script before running it on production systems
- Keep the VS Code CLI updated for security patches

## Dependencies

We regularly update dependencies via Dependabot. Security updates are prioritised.
