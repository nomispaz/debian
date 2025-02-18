#!/bin/bash

# editors
apt -t $1-backports install emacs libreoffice  

# tools
apt -t $i-backports install linux-cpupower golang vlc

# system
apt -t $i-backports install firmware-linux firmware-linux-nonfree linux-image-amd64 mesa-vdpau-drivers grub-efi-amd64 pipewire wireplumber systemd

# virtualisation
apt -t $i-backkports install qemu-utils qemu-system-x86 qemu-system-gui
