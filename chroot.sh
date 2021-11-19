#!/bin/bash

#The entire pipe has non-zero exit code when one of commands in the pipe has non-zero exit code 
set -o pipefail
# Exit on error
set -e

if [ $# -lt 5 ]; then
   echo 'bash chroot.sh USERNAME HOSTNAME ENCRYPTED_PARTITION EFI_PARTITION BIOS_DEVICE'
   echo 'CPU = amd | intel | both'
   echo 'EFI_PARTITION can be "null" for a pure BIOS system'
   echo 'BIOS_PARTITION can be "null" for a pure EFI system'
   echo 'Set both EFI_PARTITION and BIOS_PARTITION to select an hybrid MBR'
   exit 1
fi

username=$1
hostname=$2
enc_part=$3
efi_part=$4
bios_dev=$5

# Setting up localization
ln -sf /usr/share/zoneinfo/Europe/Rome /etc/localtime
# Syncronize hardware clock to system clock
hwclock --systohc

# Setting up locale
sed -i 's/#it_IT.UTF-8 UTF-8/it_IT.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo 'LANG=it_IT.UTF-8' >> /etc/locale.conf
echo 'KEYMAP=it' >> /etc/vconsole.conf 

# Setting up hostname
echo $hostname > /etc/hostname 
echo -e "127.0.0.1    localhost\n::1          localhost\n127.0.1.1    $hostname.localdomain    $hostname" > /etc/hosts

# Changing root password
passwd

# Installing base packages
pacman -Sy grub efibootmgr networkmanager wireless_tools wpa_supplicant dialog os-prober mtools dosfstools ntfs-3g base-devel linux-headers git reflector bluez bluez-utils cups xdg-utils xdg-user-dirs

# Modifying mkinitcpio to set up lvm
# Removing keyboard hook. It will be moved before
sed -i -E "s/^HOOKS=\((.*?) keyboard/HOOKS=\(\1/" /etc/mkinitcpio.conf
if [[ "$efi_part" != 'null' && "$bios_dev" != 'null' ]]; then # Installation on usb media
   # Adding encrypt and lvm2 to support encryption. Block is to be moved before autodetect, to avoid shrinking
   sed -i -E "s/^HOOKS=\((.*?) block/HOOKS=\(\1 encrypt lvm2/" /etc/mkinitcpio.conf
   # Adding block and keyboard before autodetect, avoiding shrinking them
   # Adding also keymap to read the keyboard map in /etc/vconsole.conf
   sed -i -E "s/^HOOKS=\((.*?) autodetect/HOOKS=\(\1 block keyboard autodetect keymap/" /etc/mkinitcpio.conf
else
   sed -i -E "s/^HOOKS=\((.*?) autodetect/HOOKS=\(\1 autodetect keyboard keymap/" /etc/mkinitcpio.conf
   sed -i -E "s/^HOOKS=\((.*?) block/HOOKS=\(\1 block encrypt lvm2/" /etc/mkinitcpio.conf
fi
mkinitcpio -p linux

# Installing grub
if [ "$efi_part" != 'null' ]; then
   mkdir /boot/EFI
   mount /dev/$efi_part /boot/EFI
   grub-install --target=x86_64-efi --recheck --removable --efi-directory=/boot/EFI --boot-directory=/boot
fi
if [ "$bios_dev" != 'null' ]; then
   grub-install --target=i386-pc --recheck --boot-directory=/boot /dev/$bios_dev
fi
# Getting UUID of enc_part
enc_part_uuid=$(blkid | grep $enc_part | cut -d'"' -f2)
# Modifying grug config for lvm
sed -i "s#GRUB_CMDLINE_LINUX=[\"][\"]#GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=$enc_part_uuid\:cryptlvm root=/dev/vg1/root\"#" /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

# Enabling NetworkManager, bluetooth and cups
systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable cups

# Adding user
useradd -m $username
passwd $username
usermod -aG wheel,audio,video,optical,storage $username
# Users of the wheel group can execute all commands
sed -i "s/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/" /etc/sudoers

localectl set-keymap --no-convert it

set +o pipefail
set +e
