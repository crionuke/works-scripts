#!/bin/bash
set -e

# Setup sshd, install docker, use volume

VOLUME_DIR=$1
if [ -z $VOLUME_DIR ]; then
  echo "Usage: ./use_volume.sh <volume_dir>"
  exit 1
fi

# Move home to volume
mv /home $VOLUME_DIR
ln -s $VOLUME_DIR/home /home

# Docker to volume
systemctl stop docker
mkdir -p $VOLUME_DIR/var/lib
mv /var/lib/docker $VOLUME_DIR/var/lib
ln -s $VOLUME_DIR/var/lib/docker /var/lib/docker
systemctl start docker