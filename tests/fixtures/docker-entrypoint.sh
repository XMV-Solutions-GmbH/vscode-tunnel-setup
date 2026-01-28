#!/bin/bash
# Docker entrypoint for mock server
# Initialises the environment and starts SSH

set -e

# Create required directories
mkdir -p /var/run/sshd
mkdir -p /var/run/mock-systemd
mkdir -p /etc/systemd/system

# Ensure SSH host keys exist
if [[ ! -f /etc/ssh/ssh_host_rsa_key ]]; then
    ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key -N ''
fi

if [[ ! -f /etc/ssh/ssh_host_ecdsa_key ]]; then
    ssh-keygen -t ecdsa -f /etc/ssh/ssh_host_ecdsa_key -N ''
fi

if [[ ! -f /etc/ssh/ssh_host_ed25519_key ]]; then
    ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ''
fi

# Set correct permissions
chmod 600 /etc/ssh/ssh_host_*_key
chmod 644 /etc/ssh/ssh_host_*_key.pub

# Create testuser home directory if it doesn't exist
if [[ ! -d /home/testuser ]]; then
    mkdir -p /home/testuser
    chown testuser:testuser /home/testuser
fi

# Log startup
echo "Mock server starting..."
echo "SSH listening on port 22"
echo "Test user: testuser / testpass"
echo "Root user: root / rootpass"

# Execute the main command (usually sshd)
exec "$@"
