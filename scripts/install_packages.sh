#!/bin/bash
# console
apt install alacritty fish

# tools
apt install linux-cpupower htop

# editors
apt install neovim emacs elpa-consult elpa-company elpa-go-mode elpa-rust-mode elpa-evil elpa-yasnippet elpa-yasnippet-snippets

#install windowmanager tools
apt install dunst brightnessctl wireplumber gammastep grim rofi slurp wl-clipboard

# install sway
apt install sway swaybg python3-dbus-next python3-i3ipc

# install from personal repo
apt install python3-nwg-panel network-manager-applet

# dependencies for nwg-panel
apt install git curl bluez-tools gir1.2-gtklayershell-0.1 libgtk-3-0 pulseaudio-utils gir1.2-dbusmenu-gtk3-0.4 gir1.2-playerctl-2.0 playerctl python3-dasbus python3-gi-cairo python3-i3ipc python3-netifaces python3-psutil python3-requests python3-setuptools python3-wheel sway-notification-center
