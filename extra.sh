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

# Installing paru
git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -si
cd ..
rm -rf paru

# Installing zsh and fish-like plugins
sudo pacman -Syu zsh zsh-syntax-highlighting zsh-autosuggestions
# Setting zsh as default shell
chsh -s $(which zsh)
# Installing command line utilities
sudo pacman -S z fzf fd ripgrep atool xsel ueberzug htop curl wget rsync broot tree clipmenu stow
systemctl --user enable clipmenud
paru -S up-bin

# Installing basic fonts
sudo pacman -S noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-dejavu ttf-liberation ttf-nerd-fonts-symbols
# Installing a nerd font (fira code) and a font for colored emoji
paru -S nerd-fonts-fira-code 

# Installing gpu drivers, xorg, feh (to set the wallpaper) and picom
sudo pacman -S $gpu_drivers xorg-server xorg-xinit xorg-xrandr xorg-xsetroot feh picom

# Installing pipewire and its jack plugin
# Remember to select wireplumber
paru -S pipewire pipewire-pulse pipewire-jack pipewire-jack-dropin
systemctl --user enable wireplumber 
systemctl --user enable pipewire-pulse
systemctl --user enable pipewire
# Optional: control that all is ok with "pactl info"

# Installing basic applications
sudo pacman -S firefox ranger neovim

# Optionally installing some gui based applications
#paru -S nitrogen lxappearance lxsession pcmanfm-gtk3 pavucontrol

# Installing suckless tools
cd ~/Projects
git clone https://github.com/elendi1/dwm.git
git clone https://github.com/elendi1/dwmstatus.git
git clone https://github.com/elendi1/dmenu.git
git clone https://github.com/elendi1/st.git
cd dwm
sudo make clean install
cd ../dwmstatus
sudo make clean install
cd ../dmenu
sudo make clean install
cd ../st
sudo make clean install

# Installing lvim dependencies
sudo pacman -S python-pip python-pynvim
# Installing lvim
bash <(curl -s https://raw.githubusercontent.com/lunarvim/lunarvim/master/utils/installer/install.sh)

# Cloning dotfiles into Projects and making symbolic links to it
cd ~/Projects
git clone https://github.com/elendi1/Dots.git
cd Dots
if [ "$gpu" != 'virtualbox' ]; then 
   stow -t ~ fontconfig tmux x_$resolution zsh gtk picom_vb lvim
else
   stow -t ~ fontconfig tmux x_$resolution zsh gtk picom lvim
fi

set +o pipefail
set +e
