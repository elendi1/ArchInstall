#!/bin/bash

#The entire pipe has non-zero exit code when one of commands in the pipe has non-zero exit code 
set -o pipefail
# Exit on error
set -e

if [ $# -lt 2 ]; then
   echo 'bash chroot.sh BOOT_MODE ENCRYPTED_PARTITION [EFI_MNT]'
   echo 'BOOT_MODE = uefi | bios | hybrid'
   echo 'ENCRYPTED_PARTITION is the partition used as encrypted container for the / and swap logical volumes'
   echo 'EFI_MNT is the folder where EFI was mounted'
   exit 1
fi

boot_mode=$1
enc_part=$2

if [[ "$boot_mode" == 'uefi' || "$boot_mode" == 'hybrid' ]]; then
   if [ $# -lt 3 ]; then
      echo 'Required EFI_MNT for uefi/hybrid boot mode'
      exit 1
   elif [ $# -gt 3 ]; then
      echo 'Too many parameters'
      exit 1
   fi
   efi_mnt=$3
elif [ "$boot_mode" == 'bios' ]; then
   if [ $# -gt 2 ]; then
      echo 'Too many parameters'
      exit 1
   fi
fi

# Setting up localization
ln -sf /usr/share/zoneinfo/Europe/Rome /etc/localtime
# Syncronize hardware clock to system clock
hwclock --systohc

# Setting up locale
sed -i 's/#it_IT.UTF-8 UTF-8/it_IT.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' >> /etc/locale.conf
echo 'KEYMAP=it' >> /etc/vconsole.conf 

read -p "Hostname (default=arch): " hostname 
hostname=${hostname:-arch}
# Setting up hostname
echo $hostname > /etc/hostname 
echo -e "127.0.0.1    localhost\n::1          localhost\n127.0.1.1    $hostname.localdomain    $hostname" > /etc/hosts

# Changing root password
passwd

# Installing base packages
pacman -Sy grub efibootmgr networkmanager wireless_tools wpa_supplicant dialog os-prober mtools dosfstools ntfs-3g base-devel linux-headers git reflector bluez bluez-utils cups

# Modifying mkinitcpio to set up lvm
# Removing keyboard hook. It will be moved before
sed -i -E "s/^HOOKS=\((.*?) keyboard/HOOKS=\(\1/" /etc/mkinitcpio.conf
if [ "$boot_mode" == 'hybrid' ]; then # Installation on usb media
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
if [ "$boot_mode" == 'uefi' ]; then
   grub-install --target=x86_64-efi --recheck --efi-directory=$efi_mnt
elif [ "$boot_mode" == 'bios' ]; then
   bios_dev=$(sed 's/[0-9]//' <<< $enc_part)
   grub-install --target=i386-pc --recheck --boot-directory=/boot /dev/$bios_dev
else # hybrid 
   grub-install --target=x86_64-efi --recheck --removable --efi-directory=$efi_mnt
   bios_dev=$(sed 's/[0-9]//' <<< $enc_part)
   grub-install --target=i386-pc --recheck --boot-directory=/boot /dev/$bios_dev
fi

# Getting UUID of enc_part
enc_part_uuid=$(blkid | grep $enc_part | cut -d'"' -f2)
# Modifying grub config for lvm
sed -i "s#GRUB_CMDLINE_LINUX=[\"][\"]#GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=$enc_part_uuid\:cryptlvm root=/dev/vg1/root\"#" /etc/default/grub
# Enable OS Prober
echo GRUB_DISABLE_OS_PROBER=false >> /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

# Enabling NetworkManager, bluetooth and cups
systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable cups

# Input username
read -p "Username (default=arch): " username
username=${username:-arch}
# Adding user
useradd -m $username
passwd $username
usermod -aG wheel,audio,video,optical,storage $username
# Users of the wheel group can execute all commands
sed -i "s/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/" /etc/sudoers

localectl set-keymap --no-convert it

set +o pipefail
set +e
