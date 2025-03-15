#!/bin/bash

# add official nvidia-repository for debian12
curl -fSsL https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/3bf863cc.pub | sudo gpg --dearmor | sudo tee /usr/share/keyrings/nvidia-drivers.gpg > /dev/null 2>&1
echo 'deb [signed-by=/usr/share/keyrings/nvidia-drivers.gpg] https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/ /' | sudo tee /etc/apt/sources.list.d/nvidia-drivers.list

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
sudo apt install linux-cpupower htop screenfetch

# debian dev tools
sudo apt install debmake dh-make

# security
sudo apt install clamav apparmor-profiles

# virtualisation
sudo apt install virt-manager
sudo /usr/sbin/usermod -aG libvirt simonheise

# editors
sudo apt install neovim emacs elpa-consult elpa-company elpa-go-mode elpa-rust-mode elpa-evil elpa-yasnippet elpa-yasnippet-snippets

#install windowmanager tools
sudo apt install dunst brightnessctl wireplumber gammastep grim rofi slurp wl-clipboard

# install sway
sudo apt install sway swaybg python3-dbus-next python3-i3ipc

# install from personal repo
#sudo apt install python3-nwg-panel network-manager-applet emacs-catppuccin
sudo apt install python3-nwg-panel emacs-catppuccin

# install brave
sudo apt install brave-browser

#install nvidia
sudo apt install nvidia-open
