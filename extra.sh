#!/bin/bash

#The entire pipe has non-zero exit code when one of commands in the pipe has non-zero exit code 
set -o pipefail
# Exit on error
set -e

if [ $# -lt 3 ]
then
   echo 'bash extra.sh GPU GIT_USERNAME GIT_EMAIL'
   echo 'GPU = amd | nvidia | intel | all'
   exit 1
fi

gpu=$1
git_username=$2
git_email=$3

if [ "$gpu" == 'amd' ]; then
   gpu_drivers='xf86-video-amdgpu vulkan-radeon'
elif [ "$gpu" == 'nvidia' ]; then
   gpu_drivers='xf86-video-nouveau'
elif [ "$gpu" == 'intel' ]; then
   gpu_drivers='xf86-video-intel'
elif [ "$gpu" == 'all' ]; then
   gpu_drivers='xf86-video-vesa xf86-video-ati xf86-video-intel xf86-video-amdgpu xf86-video-nouveau xf86-video-fbdev'
else
   echo 'bash extra.sh GPU GIT_USERNAME GIT_EMAIL'
   echo 'GPU = amd | nvidia | intel | all'
   exit 1
fi

# Configuring git
git config --global init.defaultBranch main
git config --global user.name "$git_username"
git config --global user.email "$git_email"
git config --global credential.helper store

# Installing paru
git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -si
cd ..
rm -rf paru

# Installing zsh
sudo pacman -Syu zsh
# Setting zsh as default shell
chsh -s $(which zsh)
# Installing zsh plugins and command line utilities
paru -S z zsh-fast-syntax-highlighting-git zsh-autosuggestions fzf fd ripgrep atool xclip ueberzug htop curl wget rsync broot starship up-bin

# Installing basic fonts
sudo pacman -S noto-fonts noto-fonts-cjk ttf-dejavu ttf-liberation
# Installing a nerd font (fira code)
paru -S nerd-fonts-fira-code

# Installing gpu drivers, xorg and feh (to set the wallpaper)
sudo pacman -S $gpu_drivers xorg-server xorg-xinit xorg-xrandr xorg-xsetroot feh
# Installing composite manager
paru -S picom-jonaburg-git

# Installing pipewire and its jack plugin
paru -S pipewire pipewire-pulse pipewire-jack pipewire-jack-dropin
systemctl --user enable pipewire-media-session.service
systemctl --user enable pipewire-pulse.service
systemctl --user enable pipewire.service
# Optional: control that all is ok with "pactl info"
# Install pavucontrol to control audio devices
sudo pacman -S pavucontrol

# Installing basic applications
pacman -S firefox ranger neovim

# Optionally installing some gui based applications
#paru -S nitrogen lxappearance lxsession pcmanfm-gtk3

# Installing suckless tools
mkdir  ~/Projects
cd ~/Projects
git clone https://github.com/elendi1/dwm.git
git clone https://github.com/elendi1/dwmblocks.git
git clone https://github.com/elendi1/dmenu.git
git clone https://github.com/elendi1/st.git
cd dwm
sudo make clean install
cd ../dwmblocks
sudo make clean install
cd ../dmenu
sudo make clean install
cd ../st
sudo make clean install
cd

set +o pipefail
set +e
