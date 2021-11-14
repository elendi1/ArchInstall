#!/bin/bash

#The entire pipe has non-zero exit code when one of commands in the pipe has non-zero exit code 
set -o pipefail
# Exit on error
set -e

if [ $# -l 2 ]
then
   echo 'bash partition.sh DISK'
   exit 1
fi

disk=$1

sgdisk -Z /dev/$disk
sgdisk -n 0:0:+200MiB -t 0:ef00 -c 0:boot /dev/$disk
sgdisk -n 0:0:0 -t 0:8e00 -c 0:root /dev/$disk

set +o pipefail
set +e
