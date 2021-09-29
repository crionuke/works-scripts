#!/bin/bash
set -e

# Setup sshd, install docker, use volume

# Setup firewall
ufw default deny incoming
ufw default allow outgoing
ufw limit 22
ufw --force enable
ufw status verbose

# Set nopasswd
sed -i 's/^%sudo.*$/%sudo ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers

# Install docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose
systemctl start docker
systemctl enable docker
