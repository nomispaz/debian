#!/bin/bash
sudo dpkg --add-architecture i386
sudo apt update
sudo apt -t bookworm-backports install steam-installer

sudo apt install mangohud
