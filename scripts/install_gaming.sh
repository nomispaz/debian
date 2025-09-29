#!/bin/bash
sudo dpkg --add-architecture i386
sudo apt update
sudo apt install steam-installer

sudo apt install mangohud

sudo apt install nvidia-driver-libs

# wine
sudo apt install wine wine64 libwine fonts-wine winetricks
