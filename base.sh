#!/bin/bash

#The entire pipe has non-zero exit code when one of commands in the pipe has non-zero exit code 
set -o pipefail
# Exit on error
set -e

if [ $# -lt 7 ]; then
   echo 'bash base.sh CPU USERNAME HOSTNAME ENCRYPTED_PARTITION EFI_PARTITION BIOS_DEVICE SWAP_SIZE'
   echo 'CPU = amd | intel | both'
   echo 'EFI_PARTITION can be "null" for a pure BIOS system'
   echo 'BIOS_PARTITION can be "null" for a pure EFI system'
   echo 'Set both EFI_PARTITION and BIOS_PARTITION to select an hybrid MBR'
   echo 'SWAP_SIZE example: 16G'
   exit 1
fi

cpu=$1
username=$2
hostname=$3
enc_part=$4
efi_part=$5
bios_dev=$6
swap_size=$7

if [ "$cpu" == 'amd' ]; then
   ucode='amd-ucode'
elif [ "$cpu" == 'intel' ]; then
   ucode='intel-ucode'
elif [ "$cpu" == 'both' ]; then
   ucode='amd-ucode intel-ucode'
else
   echo 'bash base.sh CPU USERNAME HOSTNAME ENCRYPTED_PARTITION EFI_PARTITION BIOS_DEVICE'
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
# Creating a swap logical volume of swap_size
lvcreate -L $swap_size vg1 -n swap
# Creating a root logical volume with the remaining space
lvcreate -l 100%FREE vg1 -n root

# Formatting boot and root partitions and making swap
if [ "$efi_part" != 'null' ]; then
   mkfs.fat -F32 /dev/$efi_part
fi
mkfs.ext4 /dev/vg1/root
mkswap /dev/vg1/swap

# Mounting the root partition in /mnt and mounting efi partition in /mnt/boot
mount /dev/vg1/root /mnt
mkdir /mnt/boot
mount /dev/$efi_part /mnt/boot
# Enabling swap
swapon /dev/vg1/swap

# Installing base packages
pacstrap /mnt base linux linux-firmware $ucode lvm2
# Generate filesystem table
genfstab -U /mnt >> /mnt/etc/fstab

# Copying chroot.sh into /mnt/tmp/
cp chroot.sh /mnt/
chmod +x /mnt/chroot.sh
# Chrooting into installation
arch-chroot /mnt ./chroot.sh $username $hostname $enc_part $efi_part $bios_dev
# Removing chroot.sh
rm /mnt/chroot.sh

# Copying ArchInstall folder into the previous chroot folder
mkdir /mnt/home/$username/Projects
cp -r ../ArchInstall /mnt/home/$username/Projects

echo 'Now please reboot'
echo "Run:\n"
echo "1) sudo chgrp -R $username /home/$username/Projects"
echo "2) sudo chown -R $username /home/$username/Projects"
echo '3) bash  ~/Projects/extra.sh'

set +o pipefail
set +e
