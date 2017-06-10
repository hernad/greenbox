#!/bin/sh

. /etc/green_common

if ( ! is_vbox )
then
   log_msg "automatsko kreiranje btrfs: mora biti vbox"
   exit 1
fi

DISK=/dev/sda

zfs_partition_sda_exists() {
   /sbin/fdisk $DISK -l | grep -q 0700
}

if zfs_partition_sda_exists
then
  log_msg "zfs partition on $DISK - STOP"
  exit 1
fi

vbox_extract_userdata_tar  # extract before initializing disk with btrfs

#fdisk -l /dev/$DISK >> $LOG_FILE
if btrfs inspect-internal dump-super ${DISK} | grep -q num_devices
then
  echo "${DISK} btrfs signature already exists"
else
  mkfs.btrfs -f -L "green-btrfs" $DISK
fi

btrfs inspect-internal dump-super ${DISK}  >> $LOG_FILE

mkdir -p /green-btrfs
mount $DISK /green-btrfs