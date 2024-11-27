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
echo "		         OTA Upgrade Version 1.0"
echo
echo "#########################################################################"


DOWNLOAD_URL=$3
DOWNLOAD_RETRIES=5
HASH_VALUE=$1
HASH_TYPE=$2
HASH_CMD="md5sum" 
OTA_PATH=/app_data/ota
DOWNLOAD_PATH=/app_data/ota/download
EXTRACT_CMD="tar"
EXTRACT_ARGS="xf"
EXTRACT_PATH_ARGS="-C"
EXTRACT_PATH=$DOWNLOAD_PATH/extract
UPGRADE_MANAGER="update_datalogger"
PRE_INSTALLER="pre-install"
POST_INSTALLER="post-install"

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

#ota status file holding status of ota update
OTA_STATUS_FILE=$OTA_PATH/Status.txt

## Download Path
TOP_DIR=$EXTRACT_PATH

UPGRADE_INFO_FILE=$TOP_DIR/upgrade_info.txt

#EXT Format command
LINUX_FORMAT_CMD="mkfs.ext4"

## Names of the images to grab from ftp server
BOOT_PARTITION_FILE="boot-partition.tar.gz"

## Rename rootfs as needed depending on use of tar or img
ROOTFS_PARTITION_FILE="datalogger-image-datalogger.tar.bz2"

## Diagnostic img
DIAG_PARTITION_FILE="datalogger-diagnostic-rootfs.tar.gz"

## Data img
DATA_PARTITION_FILE="data.tar.gz"

## Data img
APP_PARTITION_FILE="datalogger-app.tar.gz"

## Declare eMMC device name here
DRIVE="/dev/mmcblk0"

ROOTFS_PARTITION_TYPE="ext4"
BOOTFS_PARTITION_TYPE="vfat"

## Initialize test variable
SUCCESS=1
otaRetry=3
rootfs_updated=0
bootfs_updated=0

#read datalogger id

get_dlid() {
local key2=`cat /app_data/app_files/Dl_Info.txt | cut -d"{" -f2`
local key1=`echo $key2 | cut -d"}" -f1`
#echo $key1
for i in 1 2 3 4 
do
    local json_pair=`echo $key1 | cut -d"," -f$i`
    #echo "json_pair is :$json_pair"
    local key=`echo $json_pair | cut -d":" -f1`
    if [ "$key" == "\"Dl_Id\"" ];then
        local value=`echo $json_pair | cut -d":" -f2`
        DLID=`echo $value | cut -d"\"" -f2`
        echo "dlid is $DLID"
        break
        #return $DLID
        #echo "datalogger id matched $value $DLID"
    fi
done
}

get_dlid

OTA_TOPIC=$DLID/Ota

#send mqtt packet
timestamp=`date '+%s'`
mqttSendMessage $OTA_TOPIC "{\"Dl_Id\": \"$DLID\", \"Time\": $timestamp, \"Pkt_Type\": \"OtaStatus\", \"Status\": \"running ota_upgrade.sh\"}" $OTA_TOPIC 1 1

update_error()
{
	echo "-------------------------------------------"
	echo "Firmware Upgrade Error "
	echo "-------------------------------------------"
    #send mqtt packet
    timestamp=`date '+%s'`
    mqttSendMessage $OTA_TOPIC "{\"Dl_Id\": \"$DLID\", \"Time\": $timestamp, \"Pkt_Type\": \"OtaStatus\", \"Status\": \"Ota upgreade error occured rebooting system...\"}" $OTA_TOPIC 1 1
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

#Set the boot partition to install the upgrade
if [ "$current_bootpart" == $BOOT_PART_A ]
then
	upgrade_bootpart=$BOOT_PART_B
elif [ "$current_bootpart" == $BOOT_PART_B ]
then
	upgrade_bootpart=$BOOT_PART_A
else
	echo "Error !! Error, Invalid boot partition : $current_bootpart"
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

#Set the rootfs partition to install the upgrade
if [ "$current_rootpart" == $ROOT_PART_A ]
then
	upgrade_rootpart=$ROOT_PART_B
elif [ "$current_rootpart" == $ROOT_PART_B ]
then
	upgrade_rootpart=$ROOT_PART_A
else
	echo "Error !! Error, Invalid root partition : $current_rootpart"
	update_error
	exit -2
fi

#Run the Pre-Installer Script
if [ -f  ${TOP_DIR}/${PRE_INSTALLER} ]; then
	echo "Running Pre-Installer"
#send mqtt packet
timestamp=`date '+%s'`
mqttSendMessage $OTA_TOPIC "{\"Dl_Id\": \"$DLID\", \"Time\": $timestamp, \"Pkt_Type\": \"OtaStatus\", \"Status\": \"Running pre-installer...\"}" $OTA_TOPIC 1 1
	chmod +x ${TOP_DIR}/${PRE_INSTALLER}
	sh ${TOP_DIR}/${PRE_INSTALLER}
fi

boot_upgrade=$(( $upgrade_bits & $BOOT_BIT_POS ))
if [ "$boot_upgrade" == "$BOOT_BIT_POS" ]
then
	## Make temp directories for mountpoints
	mkdir -p /tmp_boot

	## Mount partitions for tarball extraction. 
#send mqtt packet
timestamp=`date '+%s'`
mqttSendMessage $OTA_TOPIC "{\"Dl_Id\": \"$DLID\", \"Time\": $timestamp, \"Pkt_Type\": \"OtaStatus\", \"Status\": \"Upgrading bootfs (extracting files in : $BOOTFS_PARTITION_TYPE ${DRIVE}p${upgrade_bootpart})...\"}" $OTA_TOPIC 1 1
	mount -t $BOOTFS_PARTITION_TYPE ${DRIVE}p${upgrade_bootpart} /tmp_boot

	echo "Copying Boot Files..."
	time tar -xf ${TOP_DIR}/${BOOT_PARTITION_FILE} -C /tmp_boot
	if [ $? -eq "1" ]; then
		SUCCESS=0
		echo "Error copying boot Partition image "
		update_error

		#Restore the files and reboot
		tar -xf $BACKUP_PATH/${BOOT_PARTITION_FILE} -C /tmp_boot
		sync
		sync
		umount /tmp_boot
		echo "Rebooting to Restore"
		reboot
	fi
    bootfs_updated=1
	sync
	sync
	umount /tmp_boot
	echo "Boot partition done."
    echo "bootfs_updated is ${bootfs_updated}"
    if [ "$bootfs_updated" -eq "1" ]
    then
        echo "Switching to New Upgrade bootfs"
        fw_setenv bootpart $upgrade_bootpart
        fw_setenv upgrade_bits $upgrade_bits
        fw_setenv otaRetry $otaRetry
        
        echo "Verify if bootfs upgrade is completed"
        test_bootpart=`fw_printenv bootpart | cut -d"=" -f2`
        if [ $test_bootpart -ne $upgrade_bootpart ] ; then
        	fw_setenv bootpart $upgrade_bootpart
            fw_setenv upgrade_bits $upgrade_bits
            fw_setenv otaRetry $otaRetry
        fi
    fi
fi

rootfs_upgrade=$(( $upgrade_bits & $ROOTFS_BIT_POS ))
if [ "$rootfs_upgrade" == "$ROOTFS_BIT_POS" ]
then
	mkdir -p /tmp_rootfs

#send mqtt packet
timestamp=`date '+%s'`
mqttSendMessage $OTA_TOPIC "{\"Dl_Id\": \"$DLID\", \"Time\": $timestamp, \"Pkt_Type\": \"OtaStatus\", \"Status\": \"Updating rootfs image to : ${DRIVE}p${upgrade_rootpart}\"}" $OTA_TOPIC 1 1
	mount -t $ROOTFS_PARTITION_TYPE ${DRIVE}p${upgrade_rootpart} /tmp_rootfs

	echo "Copying files into RootFS partition."

	## If using a tar archive, untar it with the below.
	time tar -xf ${TOP_DIR}/${ROOTFS_PARTITION_FILE} -C /tmp_rootfs
	if [ $? -eq "1" ]; then
		SUCCESS=0
		echo "Error copying Rootfs image"
		echo "Rebooting to Restore"
		reboot
	fi
	sync
	sync
    rootfs_updated=1
	umount /tmp_rootfs
fi

#diagrootfs_upgrade=$(( $upgrade_bits & $DIAG_BIT_POS ))
#if [ "$diagrootfs_upgrade" == "$DIAG_BIT_POS" ]
#then
        ## For diagnotic partition update
#        mkdir -p /tmp_diag

        ## Clear Cache memory
#        echo 1 > /proc/sys/vm/drop_caches

        ## mount diagnostic partition
#        mount -t $ROOTFS_PARTITION_TYPE ${DRIVE}p2 /tmp_diag

#        echo "Copying files into diagnostic partition."

#        time tar -xf ${TOP_DIR}/${DIAG_PARTITION_FILE} -C /tmp_diag
#        if [ $? -eq "1" ]; then
#                SUCCESS=1
#                echo "Error copying diagnostic image"
#                echo 0 > /sys/class/leds/mighty:red/brightness
#        fi
#        sync
#        sync
#        umount /tmp_diag
#fi

data_upgrade=$(( $upgrade_bits & $DATA_BIT_POS ))
if [ "$data_upgrade" == "$DATA_BIT_POS" ]
then
	if [ -f "${TOP_DIR}/${DATA_PARTITION_FILE}" ]
	then
		mkdir -p /tmp_data
		echo "data upgrade found"

		mount -t $ROOTFS_PARTITION_TYPE ${DRIVE}p7 /tmp_data
		if [ $? -ne "0" ]; then
        		mount -o bind /data /tmp_data
		fi

		echo "Copying files into Data partition."

		## If using a tar archive, untar it with the below.
		time tar -xf ${TOP_DIR}/${DATA_PARTITION_FILE} -C /tmp_data
		if [ $? -eq "1" ]; then
			SUCCESS=0
			echo "Error copying Data image"
			echo 0 > /sys/class/leds/mighty:red/brightness
		fi
		sync
		sync
        rootfs_updated=1
		umount /tmp_data
	fi
fi

app_upgrade=$(( $upgrade_bits & $APP_BIT_POS ))
if [ "$app_upgrade" == "$APP_BIT_POS" ]
then
	if [ -f "${TOP_DIR}/${APP_PARTITION_FILE}" ]
	then
		echo "App upgrade found"
		mkdir -p /tmp_rootfs

#send mqtt packet
timestamp=`date '+%s'`
mqttSendMessage $OTA_TOPIC "{\"Dl_Id\": \"$DLID\", \"Time\": $timestamp, \"Pkt_Type\": \"OtaStatus\", \"Status\": \"Updating application to : ${DRIVE}p${upgrade_rootpart}\"}" $OTA_TOPIC 1 1
		mount -t $ROOTFS_PARTITION_TYPE ${DRIVE}p${upgrade_rootpart} /tmp_rootfs

		echo "Copying files into App partition."

		## If using a tar archive, untar it with the below.
		time tar -xf ${TOP_DIR}/${APP_PARTITION_FILE} -C /tmp_rootfs
		if [ $? -eq "1" ]; then
			SUCCESS=0
			echo "Error copying App Image"
			echo "Rebooting to Restore"
			reboot
		fi
		sync
		sync
        rootfs_updated=1
		umount /tmp_rootfs
	fi	
fi



#Run the Post-Installer Script
if [ -f  ${TOP_DIR}/${POST_INSTALLER} ]; then
#send mqtt packet
timestamp=`date '+%s'`
mqttSendMessage $OTA_TOPIC "{\"Dl_Id\": \"$DLID\", \"Time\": $timestamp, \"Pkt_Type\": \"OtaStatus\", \"Status\": \"running post installer\"}" $OTA_TOPIC 1 1
    echo "Running Post-Installer"
    chmod +x ${TOP_DIR}/${POST_INSTALLER}
    sh ${TOP_DIR}/${POST_INSTALLER}
fi

#Change the boot partition to new
if [ "$rootfs_updated" -eq "1" ]
then
    echo "Switching to New Upgraded rootfs : ${upgrade_rootpart}"
    fw_setenv rootpart $upgrade_rootpart
    fw_setenv upgrade_bits $upgrade_bits
    fw_setenv otaRetry $otaRetry
    echo "Verify if upgrade is completed"
    test_rootpart=`fw_printenv rootpart | cut -d"=" -f2`
    if [ $test_rootpart -ne $upgrade_rootpart ] ; then
        fw_setenv rootpart $upgrade_rootpart
        fw_setenv upgrade_bits $upgrade_bits
        fw_setenv otaRetry $otaRetry
    fi
fi
sync
sync
sync

echo "Upgrade Done"

#update ota status file before restarting
if [[ $rootfs_updated -ne 0 || $bootfs_updated -ne 0 ]]
then
    if [ -f ${OTA_STATUS_FILE} ];then
        rm $OTA_STATUS_FILE 
    fi
    touch $OTA_STATUS_FILE
#echo "upgrade_bits: $upgrade_bits" >> $OTA_STATUS_FILE
        expected_bootpart=`fw_printenv bootpart | cut -d"=" -f2`
        echo "expected_bootpart:$expected_bootpart" >> $OTA_STATUS_FILE
        expected_rootpart=`fw_printenv rootpart | cut -d"=" -f2`
        echo "expected_rootpart:$expected_rootpart" >> $OTA_STATUS_FILE
    echo "ota_completed: 0" >> $OTA_STATUS_FILE
    echo "copying upgrade info file into $OTA_PATH"
    cp $UPGRADE_INFO_FILE $OTA_PATH 
fi


#send mqtt packet
timestamp=`date '+%s'`
mqttSendMessage $OTA_TOPIC "{\"Dl_Id\": \"$DLID\", \"Time\": $timestamp, \"Pkt_Type\": \"OtaStatus\", \"Status\": \"rebooting to finishup ota hold on this may take few minutes\"}" $OTA_TOPIC 1 1
reboot
