#!/bin/bash

#The entire pipe has non-zero exit code when one of commands in the pipe has non-zero exit code 
set -o pipefail
# Exit on error
set -e

if [ $# -l 6 ]
then
   echo 'bash base.sh CPU USERNAME HOSTNAME ENCRYPTED_PARTITION BOOT_PARTITION'
   echo 'CPU = amd | intel | both'
   exit 1
fi

cpu=$1
username=$2
hostname=$3
enc_part=$4
boot_part=$5

if [ "$cpu" == 'amd' ]; then
   ucode='amd-ucode'
elif [ "$cpu" == 'intel' ]; then
   ucode='intel-ucode'
elif [ "$cpu" == 'both' ]; then
   ucode='amd-ucode intel-ucode'
else
   echo 'bash base.sh CPU USERNAME HOSTNAME ENCRYPTED_PARTITION BOOT_PARTITION'
   echo 'CPU = amd | intel | both'
   exit 1
fi

# Setting up keyboard and time 
loadkeys it
timedatectl set-ntp true

# Creating an encrypted container. Choose a password for the container
cryptsetup luksFormat /dev/$enc_part
# Opening the container (inserting the password just chosen) and defining the name of encrypted logical volume (cryptlvm)
cryptsetup open /dev/$enc_part cryptlvm
# Creating a physical volume specifying the encrypted volume
pvcreate /dev/mapper/cryptlvm
# Creating the volume group
vgcreate vg1 /dev/mapper/cryptlvm
# Creating a swap logical volume of 16GB
lvcreate -L 16G vg1 -n swap
# Creating a root logical volume with the remaining space
lvcreate -l 100%FREE vg1 -n root

# Formatting boot and root partitions and making swap
mkfs.fat -F32 /dev/$boot_part
mkfs.ext4 /dev/vg1/root
mkswap /dev/vg1/swap

# Mounting the root partition in /mnt and the boot partition in /mnt/boot
mount /dev/vg1/root /mnt
mkdir /mnt/boot
mount /dev/$boot_part /mnt/boot
# Enabling swap
swapon /dev/vg1/swap

# Installing base packages
pacstrap /mnt base linux linux-firmware $ucode lvm2
# Generate filesystem table
genfstab -U /mnt >> /mnt/etc/fstab
# Chrooting into installation
arch-chroot /mnt

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
echo -e "127.0.0.1    localhost\n::1          localhost\n127.0.1.1    $hostname.localdomain    $hostname" >> /etc/hosts

# Changing root password
passwd

# Installing base packages
pacman -Sy grub efibootmgr networkmanager wireless_tools wpa_supplicant dialog os-prober mtools dosfstools ntfs-3g base-devel linux-headers git reflector bluez bluez-utils cups xdg-utils xdg-user-dirs

# Modifying mkinitcpio to set up lvm
sed -i -E "s/^HOOKS=\((.*?) autodetect/HOOKS=\(\1 autodetect keyboard keymap/" /etc/mkinitcpio.conf
sed -i -E "s/^HOOKS=\((.*?) block/HOOKS=\(\1 block encrypt lvm2/" /etc/mkinitcpio.conf
mkinitcpio -p linux

# Installing grub
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB 
# Getting UUID of enc_part
enc_part_uuid=$(blkid | grep $enc_part | cut -d'"' -f2)
# Modifying grug config for lvm
sed -i "s#GRUB_CMDLINE_LINUX=[\"][\"]#GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=$enc_part_uuid\:cryptlvm root=/dev/vg1/root\"#" /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

# Enabling NetworkManager, bluetooth and cups
systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable cupsd

# Adding user
useradd -m $username
passwd $username
usermod -aG wheel,audio,video,optical,storage $username
# Users of the wheel group can execute all commands
sed -i "s/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/" /etc/sudoers

localectl set-keymap --no-convert it

umount -a
exit

# Copying ArchInstall folder into the previous chroot folder
mkdir /mnt/home/$username/Projects
cp -r ../ArchInstall /mnt/home/$username/Projects
chgrp -R /mnt/home/$username/Projects

echo 'Now please reboot before running extra.sh'

set +o pipefail
set +e

