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
