#!/bin/bash
apt -t $1-backports install emacs linux-image-amd64 mesa-vdpau-drivers grub-efi-amd64 libreoffice golang vlc pipewire wireplumber linux-cpupower systemd firmware-linux firmware-linux-nonfree
