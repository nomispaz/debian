#!/bin/bash
nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs
nix-channel --add https://github.com/nix-community/nixGL/archive/main.tar.gz nixgl

nix-channel --update

# install nixGL to enable usage of GPU
nix-env -iA nixgl.auto.nixGLDefault

# install alacritty and neovim
nix-env -iA nixpkgs.neovim nixpkgs.alacritty

# start programs with
# ~/.nix-profile/bin/nixGL ~/.nix-profile/bin/alacritty

# alternatively install with flakes (better)
nix profile install github:nix-community/nixGL --impure

nix profile install nixpkgs#cosmic-workspaces-epoch
nix profile install nixpkgs#cosmic-term
nix profile install nixpkgs#cosmic-settings-daemon
nix profile install nixpkgs#cosmic-settings
nix profile install nixpkgs#cosmic-session
nix profile install nixpkgs#cosmic-screenshot
nix profile install nixpkgs#cosmic-randr
nix profile install nixpkgs#cosmic-panel
nix profile install nixpkgs#cosmic-osd
nix profile install nixpkgs#cosmic-notifications
nix profile install nixpkgs#cosmic-launcher
nix profile install nixpkgs#cosmic-idle
nix profile install nixpkgs#cosmic-files
nix profile install nixpkgs#cosmic-edit
nix profile install nixpkgs#cosmic-comp
nix profile install nixpkgs#cosmic-bg
nix profile install nixpkgs#cosmic-applets
nix profile install nixpkgs#cosmic-applibrary

sudo ln -s /home/simonheise/.nix-profile/bin/*cosmic* /usr/bin/
sudo ln -s /home/simonheise/.nix-profile/etc/dconf/profile/cosmic /etc/dconf/profile/cosmic
sudo ln -s /home/simonheise/.nix-profile/lib/systemd/user/cosmic-session.target /lib/systemd/user/cosmic-session.target

