#!/usr/bin/env bash
set -ex

sleep 15 | echo "Script waits for 15 seconds"

# ebs volume will be mounted
if ! mountpoint -q /mnt/data; then
  mount -t ext4 /dev/disk/by-uuid/63fdf236-83be-4fbb-9d1b-c0681da39ccb /mnt/data
  sleep 1
  echo "/dev/disk/by-uuid/63fdf236-83be-4fbb-9d1b-c0681da39ccb /mnt/data ext4 defaults,noatime 0 0" >> /etc/fstab
fi

