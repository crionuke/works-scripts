#!/bin/bash
set -e

# Add new vm user with authorized key from root user

USER_NAME=$1
if [ -z $USER_NAME ]; then
  echo "Usage: ./add_user.sh <user_name>"
  exit 1
fi

# Create user
adduser --shell /bin/bash --disabled-password --gecos "" $USER_NAME
adduser $USER_NAME docker
# Setup ssh
mkdir /home/$USER_NAME/.ssh
chown $USER_NAME:$USER_NAME /home/$USER_NAME/.ssh
chmod 700 /home/$USER_NAME/.ssh
cp /root/.ssh/authorized_keys /home/$USER_NAME/.ssh/
chown $USER_NAME:$USER_NAME /home/$USER_NAME/.ssh/authorized_keys
# Sudo
usermod -aG sudo $USER_NAME