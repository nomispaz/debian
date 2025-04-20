#!/bin/bash

# editors
sudo apt -t $1-backports install emacs libreoffice  

# tools
sudo apt -t $1-backports install linux-cpupower golang vlc

# system
sudo apt -t $1-backports install firmware-linux firmware-linux-nonfree linux-image-amd64 mesa-vdpau-drivers grub-efi-amd64 pipewire wireplumber

# virtualisation
sudo apt -t $1-backports install qemu-utils qemu-system-x86 qemu-system-gui
