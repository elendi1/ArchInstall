#!/bin/bash

# The entire pipe has non-zero exit code when one of commands in the pipe has non-zero exit code 
set -o pipefail
# Exit on error
set -e

if [ $# -lt 3 ]; then
   echo 'bash base.sh BOOT_MODE BOOT_PARTITION ENCRYPTED_PARTITION [EFI_PARTITION]'
   echo 'BOOT_MODE = uefi | bios | hybrid'
   echo 'BOOT_PARTITION is the unencrypted partition where /boot is mounted. Can be equal to EFI_PARTITION'
   echo 'ENCRYPTED_PARTITION is the partition used as encrypted container for the / and swap logical volumes'
   echo 'EFI_PARTITION is EFI system partition that must be specified only for uefi/hybrid boot mode'
   exit 1
fi

boot_mode=$1
boot_part=$2
enc_part=$3

if [[ "$boot_mode" == 'uefi' || "$boot_mode" == 'hybrid' ]]; then
   if [ $# -lt 4 ]; then
      echo 'Required EFI_PARTITION for uefi/hybrid boot mode'
      exit 1
   elif [ $# -gt 4 ]; then
      echo 'Too many parameters'
      exit 1
   fi
   efi_part=$4
elif [ "$boot_mode" == 'bios' ]; then
   if [ $# -gt 3 ]; then
      echo 'Too many parameters'
      exit 1
   fi
fi

# Setting up keyboard and time 
loadkeys it
timedatectl set-ntp true

# Input swap size
read -p "Insert swap partition size (default=4G, 0 to avoid swap partition creation): " swap_size
swap_size="${swap_size:-4G}"

# Creating an encrypted container. Choose a password for the container
cryptsetup luksFormat /dev/$enc_part
# Opening the container (inserting the password just chosen) and defining the name of encrypted logical volume (cryptlvm)
cryptsetup open /dev/$enc_part cryptlvm
# Creating a physical volume specifying the encrypted volume
pvcreate /dev/mapper/cryptlvm
# Creating the volume group
vgcreate vg1 /dev/mapper/cryptlvm
if [ "$swap_size" != '0' ]; then
   # Creating a swap logical volume of swap_size
   lvcreate -L $swap_size vg1 -n swap
fi
# Creating a root logical volume with the remaining space
lvcreate -l 100%FREE vg1 -n root

# Formatting boot and root partitions and making swap (in case greater than 0)
mkfs.ext4 /dev/vg1/root
if [ "$swap_size" != '0' ]; then
   mkswap /dev/vg1/swap
fi

# Mounting root, boot and efi (in case available)
mount /dev/vg1/root /mnt
mkdir /mnt/boot
if [ "$boot_mode" == "bios" ]; then
   mkfs.ext4 /dev/$boot_part
   mount /dev/$boot_part /mnt/boot
   efi_mnt=''
else # uefi and hybrid
   read -p 'Do you want to format the EFI partition? [y/N]: ' format_efi
   if [ "$format_efi" == "y" ]; then
      mkfs.fat -F32 /dev/$efi_part
   fi
   if [ $efi_part == $boot_part ]; then
      mount /dev/$efi_part /mnt/boot
      efi_mnt='/boot'
   else
      mkfs.ext4 /dev/$boot_part
      mount /dev/$boot_part /mnt/boot
      mkdir /mnt/boot/EFI
      mount /dev/$efi_part /mnt/boot/EFI
      efi_mnt='/boot/EFI'
   fi
fi

if [ "$swap_size" != '0' ]; then
   # Enabling swap
   swapon /dev/vg1/swap
fi

# Input of ucode
read -p "Select ucode: amd-ucode (1), intel-ucode (2), both (3): " ucode_id
if [ "$ucode_id" == '1' ]; then
   ucode='amd-ucode'
elif [ "$ucode_id" == '2' ]; then
   ucode='intel-ucode'
elif [ "$ucode_id" == '3' ]; then
   ucode='amd-ucode intel-ucode'
else
   echo 'Wrong ucode id selected'
   exit 1
fi

# Installing base packages
pacstrap /mnt base linux linux-firmware $ucode lvm2
# Generate filesystem table
genfstab -U /mnt >> /mnt/etc/fstab

# Copying chroot.sh into /mnt/tmp/
cp chroot.sh /mnt/
chmod +x /mnt/chroot.sh
# Chrooting into installation
arch-chroot /mnt ./chroot.sh $boot_mode $enc_part $efi_mnt 
# Removing chroot.sh
rm /mnt/chroot.sh

# Copying ArchInstall folder into the previous chroot folder
username=$(ls /mnt/home/)
mkdir /mnt/home/$username/Projects
cp -r ../ArchInstall /mnt/home/$username/Projects

echo 'Now please reboot'
echo "Run:\n"
echo "1) sudo chgrp -R $username /home/$username/Projects"
echo "2) sudo chown -R $username /home/$username/Projects"
echo '3) bash  ~/Projects/extra.sh'

set +o pipefail
set +e
