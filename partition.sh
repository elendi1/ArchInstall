#!/bin/bash

#The entire pipe has non-zero exit code when one of commands in the pipe has non-zero exit code 
set -o pipefail
# Exit on error
set -e

if [ $# -lt 2 ]
then
   echo 'bash partition.sh DISK MBR'
   echo 'MBR = efi | bios | hybrid'
   exit 1
fi

disk=$1
mbr=$2

if [ "$mbr" == 'efi' ]; then
   sgdisk -Z /dev/$disk
   sgdisk -n 0:0:+200MiB -t 0:ef00 -c 0:efi /dev/$disk
   sgdisk -n 0:0:0 -t 0:8e00 -c 0:root /dev/$disk
elif [ "$mbr" == 'bios' ]; then
   sgdisk -Z /dev/$disk
   sgdisk -n 0:0:+1MiB -t 0:ef02 -c 0:bios /dev/$disk
   sgdisk -n 0:0:+200MiB -t 0:8e00 -c 0:boot /dev/$disk
   sgdisk -n 0:0:0 -t 0:8e00 -c 0:root /dev/$disk
   exit 1
elif [ "$mbr" == 'hybrid' ]; then
   sgdisk -Z /dev/$disk
   sgdisk -n 0:0:+1MiB -t 0:ef02 -c 0:bios /dev/$disk
   sgdisk -n 0:0:+200MiB -t 0:ef00 -c 0:efi /dev/$disk
   sgdisk -n 0:0:0 -t 0:8e00 -c 0:root /dev/$disk
   echo -e 'r\nh\n1 2 3\nN\n\nN\n\nN\n\nY\nx\nh\nw\nY\n' | gdisk /dev/$disk
else
   echo 'bash partition.sh DISK MBR'
   echo 'MBR = efi | bios | hybrid'
   exit 1
fi

set +o pipefail
set +e
