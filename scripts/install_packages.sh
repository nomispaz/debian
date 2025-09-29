#!/bin/bash

# add personal repository from opensuse buildservice
echo 'deb http://download.opensuse.org/repositories/home:/nomispaz:/debian/Debian_13/ /' | sudo tee /etc/apt/sources.list.d/home:nomispaz:debian.list
curl -fsSL https://download.opensuse.org/repositories/home:nomispaz:debian/Debian_13/Release.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/home_nomispaz_debian.gpg > /dev/null

echo 'deb http://download.opensuse.org/repositories/home:/nomispaz:/debian:/kernel/Debian_13/ /' | sudo tee /etc/apt/sources.list.d/home:nomispaz:debian:kernel.list
curl -fsSL https://download.opensuse.org/repositories/home:nomispaz:debian:kernel/Debian_13/Release.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/home_nomispaz_debian_kernel.gpg > /dev/null

echo 'deb http://download.opensuse.org/repositories/home:/nomispaz:/debian:/emacs/Debian_13/ /' | sudo tee /etc/apt/sources.list.d/home:nomispaz:debian:emacs.list
curl -fsSL https://download.opensuse.org/repositories/home:nomispaz:debian:emacs/Debian_13/Release.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/home_nomispaz_debian_emacs.gpg > /dev/null

# add brave repository
sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main"|sudo tee /etc/apt/sources.list.d/brave-browser-release.list

# update repository cache
sudo apt update

# console
sudo apt install alacritty fish

# tools
sudo apt install linux-cpupower htop screenfetch keepassxc vlc obs-studio meld blueman gparted

# debian dev tools
sudo apt install debmake dh-make

# security
sudo apt install clamav apparmor-profiles apparmor

# virtualisation
sudo apt install virt-manager
sudo /usr/sbin/usermod -aG libvirt simonheise
sudo apt install podman

# editors
sudo apt install neovim emacs elpa-consult elpa-company elpa-go-mode elpa-markdown-mode elpa-rust-mode elpa-evil elpa-yasnippet elpa-yasnippet-snippets

# fonts
sudo apt install fonts-font-awesome fonts-dejavu

# additional programs
sudo apt install calibre thunderbird

#install windowmanager tools
sudo apt install dunst brightnessctl wireplumber gammastep grim rofi slurp wl-clipboard network-manager-gnome pavucontrol

# install sway
sudo apt install sway swaybg python3-dbus-next python3-i3ipc

# install from personal repo
#sudo apt install python3-nwg-panel network-manager-applet emacs-catppuccin
sudo apt install python3-nwg-panel emacs-catppuccin emacs-cape emacs-elixir-mode cpupower-go veracrypt

# dependencies for nwg-panel
apt install git curl bluez-tools gir1.2-gtklayershell-0.1 libgtk-3-0 pulseaudio-utils gir1.2-dbusmenu-gtk3-0.4 gir1.2-playerctl-2.0 playerctl python3-dasbus python3-gi-cairo python3-i3ipc python3-netifaces python3-psutil python3-requests python3-setuptools python3-wheel sway-notification-center

# install brave
sudo apt install brave-browser

# install dkms for nvidia
sudo apt install dkms

# flatpak
sudo apt install flatpak
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
###################################
#Note that the directories

#'/var/lib/flatpak/exports/share'
#'/home/simonheise/.local/share/flatpak/exports/share'

#are not in the search path set by the XDG_DATA_DIRS environment variable, so
#applications installed by Flatpak may not appear on your desktop until the
#session is restarted.
###################################
flatpak install flathub com.usebottles.bottles
flatpak install flathub com.github.tchx84.Flatseal
# flatpak run com.usebottles.bottles
# flatpak run com.github.tchx84.Flatseal
#

# programming
sudo apt install rustup golang gopls elixir elixir-ls erlang default-jdk jdtls maven gradle
rustup default stable
rustup component add rust-analyzer rust-src

# osc as a cli for opensuse buildservice
sudo apt install osc

# cosmic desktop
sudo apt install cosmic-comp cosmic-launcher cosmic-panel cosmic-session cosmic-settings cosmic-applets

# niri and cosmic integration
sudo apt install niri xwayland-satellite cosmic-ext-extra-session
