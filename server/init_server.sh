#!/bin/bash
set -e

# Setup firewall and sudoers with nopasswd

# Setup firewall
ufw default deny incoming
ufw default allow outgoing
ufw limit 22
ufw --force enable
ufw status verbose

# Set nopasswd
sed -i 's/^%sudo.*$/%sudo ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers
