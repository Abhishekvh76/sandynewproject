#!/bin/sh
#/****************************************************************************
# * Copyright (C) 2020 by Unizen Technologies				     *
# *                                                                          *
# *                                                                          *
# ****************************************************************************/

#/**
# * @file ota_upgrade_manager
# * @author sunil Adhikari <sunilk@unizentechnologies.com>
# * @date june 1 2020
# * @brief Provides Upgrade Service for datalogger
# *
# */


echo "#########################################################################"
echo
echo "		         OTA Downgrade Version 1.0"
echo
echo "#########################################################################"


OTA_PATH=/app_data/ota
DOWNLOAD_PATH=/app_data/ota/download

MMC_BOOT1_DEV="/dev/mmcblk0p1"
MMC_BOOT2_DEV="/dev/mmcblk0p2"
MMC_APP_DATA_DEV="/dev/mmcblk0p3"
MMC_ROOTFS1_DEV="/dev/mmcblk0p5"
MMC_ROOTFS2_DEV="/dev/mmcblk0p6"
MMC_DOWNLOAD_DEV="/dev/mmcblk0p7"

TMP_ROOT_PATH="/usr/bin/"
BOOT_MNT_PATH="/preboot"
DIAG_ROOT_MNT_PATH="/diag_root"
BACKUP_MNT_PATH="/backup"
BACKUP_PATH="/backup"
ROOTFS_MNT_PATH="/prod_root"
DATA_MNT_PATH="/data"
DOWNLOAD_MNT_PATH="/download"
SWAP_MNT_PATH="/swap"

ROOT_PART_A="5"
ROOT_PART_B="6"

BOOT_PART_A="1"
BOOT_PART_B="2"

BOOT_BIT_POS=1
APPDATA_BIT_POS=2
ROOTFS_BIT_POS=4
LOGDATA_BIT_POS=8
APP_BIT_POS=16
DATA_BIT_POS=32

#path for files of Dog Application
DOG_APP_DATA_PATH=/app_data/DogApp/
DOWNGRADE_STATUS_FILE=$DOG_APP_DATA_PATH/downgradeStatus.txt

#ota status file holding status of ota update
OTA_STATUS_FILE=$OTA_PATH/Status.txt

## Download Path
TOP_DIR=$EXTRACT_PATH

UPGRADE_INFO_FILE=$OTA_PATH/upgrade_info.txt

## Declare eMMC device name here
DRIVE="/dev/mmcblk0"

ROOTFS_PARTITION_TYPE="ext4"
BOOTFS_PARTITION_TYPE="vfat"

## Initialize test variable
SUCCESS=1
otaRetry=3
rootfs_updated=0
bootfs_updated=0


update_error()
{
	echo "-------------------------------------------"
	echo "Firmware Upgrade Error "
	echo "-------------------------------------------"
	sync
	sleep 5
	reboot
}

upgrade_bits=`cat $UPGRADE_INFO_FILE | grep upgrade | cut -d"=" -f2`
clean_bits=`cat $UPGRADE_INFO_FILE | grep clean | cut -d"=" -f2`
partition_reqd=`cat $UPGRADE_INFO_FILE | grep partition | cut -d"=" -f2`

# Sanity Check
if [ -z "$upgrade_bits" ]
then
	echo "Error !! Invalid no.o of arguments"
	update_error
	exit -2
fi

# Get the current good partition
current_bootpart=`fw_printenv bootpart | cut -d"=" -f2`
if [ -z "$current_bootpart" ]
then
	echo "Error !! Error, boot partition not found"
	update_error
	exit -2
fi


# Get the current good partition
current_rootpart=`fw_printenv rootpart | cut -d"=" -f2`
if [ -z "$current_rootpart" ]
then
	echo "Error !! Error, root partition not found"
	update_error
	exit -2
fi

boot_upgrade=$(( $upgrade_bits & $BOOT_BIT_POS ))
if [ "$boot_upgrade" == "$BOOT_BIT_POS" ]
then
    #Set the boot partition to install the upgrade
    if [ "$current_bootpart" == $BOOT_PART_A ]
    then
        downgrade_bootpart=$BOOT_PART_B
    elif [ "$current_bootpart" == $BOOT_PART_B ]
    then
        downgrade_bootpart=$BOOT_PART_A
    else
        echo "Error !! Error, Invalid boot partition : $current_bootpart"
        update_error
        exit -2
    fi
    echo "Switching to New downgraded bootfs $downgrade_bootpart"
    fw_setenv bootpart $downgrade_bootpart

    echo "Verify if bootfs downgrade is completed"
    test_bootpart=`fw_printenv bootpart | cut -d"=" -f2`
    if [ $test_bootpart -ne $downgrade_bootpart ] ; then
        fw_setenv bootpart $downgrade_bootpart
    fi
fi

rootfs_upgrade=$(( $upgrade_bits & $ROOTFS_BIT_POS ))
if [ "$rootfs_upgrade" == "$ROOTFS_BIT_POS" ]
then
    #Set the rootfs partition to install the upgrade
    if [ "$current_rootpart" == $ROOT_PART_A ]
    then
        downgrade_rootpart=$ROOT_PART_B
    elif [ "$current_rootpart" == $ROOT_PART_B ]
    then
        downgrade_rootpart=$ROOT_PART_A
    else
        echo "Error !! Error, Invalid root partition : $current_rootpart"
        update_error
        exit -2
    fi
    echo "Switching to New doengrade rootfs : ${downgrade_rootpart}"
    fw_setenv rootpart $downgrade_rootpart
    test_rootpart=`fw_printenv rootpart | cut -d"=" -f2`
    if [ $test_rootpart -ne $downgrade_rootpart ] ; then
        fw_setenv rootpart $downgrade_rootpart
    fi

fi

#remove ota status file and clear downgrade status file
rm $OTA_STATUS_FILE
if [ ! -d $DOG_APP_DATA_PATH ]; then
    echo "making path :$DOG_APP_DATA_PATH"
    mkdir -p $DOG_APP_DATA_PATH
fi
rm $DOWNGRADE_STATUS_FILE
touch $DOWNGRADE_STATUS_FILE

echo "rootpart:$downgrade_rootpart" >> $DOWNGRADE_STATUS_FILE
echo "bootpart:$downgrade_bootpart" >> $DOWNGRADE_STATUS_FILE
echo "status_response:0" >> $DOWNGRADE_STATUS_FILE
sync
sync
sync

echo "Downgrade Done"

#send message stating downgrade is done

#sleep 2
#reboot
