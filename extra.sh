#!/bin/bash

#The entire pipe has non-zero exit code when one of commands in the pipe has non-zero exit code 
set -o pipefail
# Exit on error
set -e

if [ $# -lt 4 ]
then
   echo 'bash extra.sh GPU GIT_USERNAME GIT_EMAIL RESOLUTION'
   echo 'GPU = amd | nvidia | intel | all | virtualbox'
   echo 'RESOLUTION = fhd | 4k'
   exit 1
fi

gpu=$1
git_username=$2
git_email=$3
resolution=$4

if [ "$gpu" == 'amd' ]; then
   gpu_drivers='xf86-video-amdgpu vulkan-radeon'
elif [ "$gpu" == 'nvidia' ]; then
   gpu_drivers='xf86-video-nouveau'
elif [ "$gpu" == 'intel' ]; then
   gpu_drivers='xf86-video-intel'
elif [ "$gpu" == 'all' ]; then
   gpu_drivers='xf86-video-vesa xf86-video-ati xf86-video-intel xf86-video-amdgpu xf86-video-nouveau xf86-video-fbdev'
elif [ "$gpu" == 'virtualbox' ]; then
   gpu_drivers='virtualbox-guest-utils'
else
   echo 'bash extra.sh GPU GIT_USERNAME GIT_EMAIL'
   echo 'GPU = amd | nvidia | intel | all | virtualbox'
   exit 1
fi

# Configuring git
git config --global init.defaultBranch main
git config --global user.name "$git_username"
git config --global user.email "$git_email"
git config --global credential.helper store

# Installing pikaur
git clone https://aur.archlinux.org/pikaur.git
cd pikaur
makepkg -si
cd ..
rm -rf pikaur

# Installing zsh and fish-like plugins
sudo pacman -Syu zsh zsh-syntax-highlighting zsh-autosuggestions
# Setting zsh as default shell
chsh -s $(which zsh)
# Installing command line utilities
sudo pacman -S z fzf fd ripgrep atool xsel ueberzug htop curl wget rsync broot tree clipmenu stow tmux openssh
systemctl --user enable clipmenud
pikaur -S up-bin

# Installing basic fonts
sudo pacman -S noto-fonts noto-fonts-emoji ttf-dejavu ttf-liberation ttf-nerd-fonts-symbols
read -p "Do you want to install noto-fonts-cjk? [y/N]: " cjk
if [ "$cjk" == 'y' ]; then
   pacman -S noto-fonts-cjk
fi
# Installing a nerd font (fira code) and a font for colored emoji
pikaur -S nerd-fonts-fira-code 

# Installing gpu drivers, xorg, feh (to set the wallpaper) and picom
sudo pacman -S $gpu_drivers xorg-server xorg-xinit xorg-xrandr xorg-xsetroot feh picom

# Installing pipewire and its jack plugin
# Remember to select wireplumber
pikaur -S pipewire pipewire-pulse pipewire-jack pipewire-jack-dropin
systemctl --user enable wireplumber 
systemctl --user enable pipewire-pulse
systemctl --user enable pipewire
# Optional: control that all is ok with "pactl info"

# Installing basic applications
sudo pacman -S firefox ranger neovim

# Installing audio/video basic tools
sudo pacman -S mpv youtube-dl

# Installing suckless tools
cd ~/Projects
git clone https://github.com/elendi1/dwm.git
git clone https://github.com/elendi1/dwmstatus.git
git clone https://github.com/elendi1/dmenu.git
git clone https://github.com/elendi1/st.git
git clone https://github.com/koiosdev/Tokyo-Night-Linux.git
cd dwm
sudo make clean install
cd ../dwmstatus
sudo make clean install
cd ../dmenu
sudo make clean install
cd ../st
sudo make clean install
cd ..
mkdir /usr/share/themes/TokyoNight
cp -r Tokyo-Night-Linux/chrome Tokyo-Night-Linux/gtk* /usr/share/themes/TokyoNight
rm -rf Tokyo-Night-Linux

# Installing lvim dependencies
sudo pacman -S python-pip python-pynvim
# Installing lvim
bash <(curl -s https://raw.githubusercontent.com/lunarvim/lunarvim/master/utils/installer/install.sh)
# Removing config file. It will be replaced by the symlink in the dots
rm ~/.config/lvim/config.lua

# Installing rootless podman
sudo touch /etc/subuid /etc/subgid
sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 $USERNAME
podman system migrate

read -p "Do you want to install Bitwig?" bitwig
if [ "$bitwig" == 'y' ]; then
   # Installing Bitwig-Studio and its dependency
   pikaur -S libxkbcommon-x11 bitwig-studio
fi

read -p "Do you want to install Reamp Studio dependencies?" reamp
if [ "$reamp" == 'y' ]; then
   # Dependency of ReAmp Studio
   pacman -S llibcurl-gnutls
fi

# Cloning dotfiles into Projects and making symbolic links to it
cd ~/Projects
git clone https://github.com/elendi1/Dots.git
cd Dots
if [ "$gpu" != 'virtualbox' ]; then 
   stow -t ~ fontconfig tmux x_$resolution zsh gtk picom_vb lvim
else
   stow -t ~ fontconfig tmux x_$resolution zsh gtk picom lvim
fi

pacman -Scc

set +o pipefail
set +e
