#!/bin/bash

sudo apt install snapper grub-btrfs

sudo umount /.snapshots
    sudo rm -r /.snapshots
    sudo snapper -c root create-config /

        # Use Bash syntax for setting rootUUID
        rootUUID=$(grep -E '^[^#].*\s/\s.*btrfs.*subvol=(/@)' /etc/fstab | awk '{print $1}' | sed 's/^UUID=//')

    # Mount the snapshots subvolume
    sudo mount -o subvol=snapshots UUID=$rootUUID /.snapshots
