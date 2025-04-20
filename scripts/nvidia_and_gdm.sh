#!/bin/bash
# manually: add nvidia-drm.nomodeset=1 to grub command line

# this again enables wayland sessions for gdm with nvidia
sudo ln -s /dev/null /etc/udev/rules.d/61-gdm.rules
