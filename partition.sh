#!/bin/bash

if [ $# -l 2 ]
then
    echo 'sh partition.sh HARD_DISK'
fi

hd=$1

sgdisk -Z /dev/$hd
sgdisk -n 0:0:+200MiB -t 0:ef00 -c 0:boot /dev/$hd
sgdisk -n 0:0:0 -t 0:8e00 -c 0:root /dev/$hd

