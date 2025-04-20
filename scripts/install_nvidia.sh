#!/bin/bash

# add official nvidia-repository for debian12
curl -fSsL https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/3bf863cc.pub | sudo gpg --dearmor | sudo tee /usr/share/keyrings/nvidia-drivers.gpg > /dev/null 2>&1
echo 'deb [signed-by=/usr/share/keyrings/nvidia-drivers.gpg] https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/ /' | sudo tee /etc/apt/sources.list.d/nvidia-drivers.list

sudo apt update

#install nvidia
sudo apt install nvidia-open nvidia-prime

# libwlroots from personal repo
sudo apt install libwlroots10

# setup nvidia to be used by podman
sudo apt install nvidia-container-toolkit
sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml
