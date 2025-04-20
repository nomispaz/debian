#!/bin/bash

    # Define the path to fstab
    set FSTAB_FILE "/etc/fstab"
        echo "Not running in Fish shell"
        # Use Bash syntax for setting rootUUID
        rootUUID=$(grep -E '^[^#].*\s/\s.*btrfs.*subvol=(/)?root' /etc/fstab | awk '{print $1}' | sed 's/^UUID=//')

    # Mount the snapshots subvolume
    sudo mount -o subvol=snapshots UUID=$rootUUID /.snapshots
