#!/bin/bash

# add personal repository from opensuse buildservice
echo 'deb http://download.opensuse.org/repositories/home:/nomispaz:/debian/Debian_12/ /' | sudo tee /etc/apt/sources.list.d/home:nomispaz:debian.list
curl -fsSL https://download.opensuse.org/repositories/home:nomispaz:debian/Debian_12/Release.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/home_nomispaz_debian.gpg > /dev/null

# add brave repository
sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main"|sudo tee /etc/apt/sources.list.d/brave-browser-release.list

# update repository cache
sudo apt update

# console
sudo apt install alacritty fish

# tools
sudo apt install linux-cpupower htop screenfetch keepassxc

# debian dev tools
sudo apt install debmake dh-make

# security
sudo apt install clamav apparmor-profiles apparmor

# virtualisation
sudo apt install virt-manager
sudo /usr/sbin/usermod -aG libvirt simonheise
sudo apt install podman

# editors
sudo apt install neovim emacs elpa-consult elpa-company elpa-go-mode elpa-rust-mode elpa-evil elpa-yasnippet elpa-yasnippet-snippets

# fonts
sudo apt install fonts-font-awesome fonts-dejavu

# additional programs
sudo apt install calibre thunderbird

#install windowmanager tools
sudo apt install dunst brightnessctl wireplumber gammastep grim rofi slurp wl-clipboard network-manager-gnome

# install sway
sudo apt install sway swaybg python3-dbus-next python3-i3ipc

# install from personal repo
#sudo apt install python3-nwg-panel network-manager-applet emacs-catppuccin
sudo apt install python3-nwg-panel emacs-catppuccin cpupower-go veracrypt

# dependencies for nwg-panel
apt install git curl bluez-tools gir1.2-gtklayershell-0.1 libgtk-3-0 pulseaudio-utils gir1.2-dbusmenu-gtk3-0.4 gir1.2-playerctl-2.0 playerctl python3-dasbus python3-gi-cairo python3-i3ipc python3-netifaces python3-psutil python3-requests python3-setuptools python3-wheel sway-notification-center

# install brave
sudo apt install brave-browser

