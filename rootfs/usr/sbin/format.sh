#!/bin/sh
echo "****************************************************"
echo "Formatting Script - 07/10/2020         "
echo "                              by Sunil Adhikari"
echo "****************************************************"

Help()
{
   # Display Help
   echo ""
   echo
   echo "Syntax: sudo format.sh <Clean_bits>"
   echo "Clean_bits options:"
   echo "           BOOT_BIT_POS=1"
   echo "           APPDATA_BIT_POS=2"
   echo "           ROOTFS_BIT_POS=4"
   echo "           LOGDATA_BIT_POS=8"
   echo "           APP_BIT_POS=16"
   echo "           DATA_BIT_POS=32"
   echo "           BOOTBAK_BIT_POS=64"
   echo "           ROOTFSBAK_BIT_POS=128"
   echo 
   echo "for multiple options please add these bits" 
   echo
}

################### Help Messages ############################################
while getopts ":h" option; do
   case $option in
      h) # display Help
         Help
         exit;;
     \?) # incorrect option
         echo "Error: Invalid option"
         exit;;
   esac
done


################### Validataions ############################################

#ask user to run script with sudo 
if ! [ $(id -u) = 0 ]; then
   echo "The script need to be run as root." >&2
   echo "Usage:sudo $0 <sdcard device(e.g. /dev/mmcblk0/1...)> <clean_bits (for info run help)>"
   exit 1
fi

## Declare sdCard device name here
DRIVE=$1
clean_bits=$2


#validate arguments count
if [ "X$DRIVE" == "X" ]
then
    echo "Usage:sudo $0 <sdcard device(e.g. /dev/mmcblk0/1...)> <clean_bits (for info run help)>"
        exit -1
fi

if [ "X$clean_bits" == "X" ]
then
    echo "Usage:sudo $0 <sdcard device(e.g. /dev/mmcblk0/1...)> <clean_bits (for info run help)>"
        exit -1
fi


check_mounted(){
  is_mounted=$(grep ${DRIVE}p /proc/mounts | awk '{print $2}')
  echo "Mounted Partitions are : $is_mounted"

  if grep -q ${DRIVE}p /proc/mounts; then
      echo "Found mounted partition(s) on " ${DRIVE}": " $is_mounted
      counter=1
      for i in $is_mounted; do \
	  echo "Unmounting $i"
      	  umount $i
          echo "4k erase on ${DRIVE}p${counter}"; 
          dd if=/dev/zero of=${DRIVE}p${counter} bs=4k count=1;
          counter=$((counter+1));
      done
  else
      echo "No partition found. Continuing."
  fi
}

STARTTIME=$(date +%s)
check_mounted


##---------Start of variables---------------------##
BOOT_BIT_POS=1
APPDATA_BIT_POS=2
ROOTFS_BIT_POS=4
LOGDATA_BIT_POS=8
APP_BIT_POS=16
DATA_BIT_POS=32
BOOTBAK_BIT_POS=64
ROOTFSBAK_BIT_POS=128

#EXT Format command
LINUX_FORMAT_CMD="mkfs.ext4"
FAT_FORMAT_CMD="mkfs.vfat"


## Initialize test variable
SUCCESS=1

##----------End of variables-----------------------##


#Check for BOOT Partition 
clean_reqd=$(( $clean_bits & $BOOT_BIT_POS))
if [ "$clean_reqd" == "$BOOT_BIT_POS" ]
then
	## Format the boot1 partition to fat32
	$FAT_FORMAT_CMD -F 32 -n "boot1" ${DRIVE}p1
    echo "boot1(${DRIVE}p1) partition format done."
    echo "********************************************"
fi

#Check for BOOT Partition 
clean_reqd=$(( $clean_bits & $BOOTBAK_BIT_POS))
if [ "$clean_reqd" == "$BOOTBAK_BIT_POS" ]
then
	## Format the boot2 partition to fat32
	$FAT_FORMAT_CMD -F 32 -n "boot2" ${DRIVE}p2
    echo "boot2(${DRIVE}p2) partition format done."
    echo "********************************************"
fi

#Check for App_Data Partition
clean_reqd=$(( $clean_bits & $APPDATA_BIT_POS))
if [ "$clean_reqd" == "$APPDATA_BIT_POS" ]
then
	## Format the Appdata partition
	$LINUX_FORMAT_CMD -q -L "app_data" ${DRIVE}p3
    echo "app_data(${DRIVE}p3) partition format done."
    echo "********************************************"
fi

#Check for Rootfs1 Partition
clean_reqd=$(( $clean_bits & $ROOTFS_BIT_POS))
if [ "$clean_reqd" == "$ROOTFS_BIT_POS" ]
then
	## Format the rootfs to ext3 (or ext4, etc.) if using a tar file.
	## We DO NOT need to format this partition if we are 'dd'ing an image
	## Comment out this line if using 'dd' of an image.
	$LINUX_FORMAT_CMD -q -L "rootfs1" ${DRIVE}p5
    echo "rootfs1(${DRIVE}p5) partition done."
    echo "********************************************"
fi

#Check for RootFS2 Partition
clean_reqd=$(( $clean_bits & $ROOTFSBAK_BIT_POS))
if [ "$clean_reqd" == "$ROOTFSBAK_BIT_POS" ]
then
	## Format the rootfs to ext3 (or ext4, etc.) if using a tar file.
	## We DO NOT need to format this partition if we are 'dd'ing an image
	## Comment out this line if using 'dd' of an image.
	$LINUX_FORMAT_CMD -q -L "rootfs2" ${DRIVE}p6
    echo "rootfs2(${DRIVE}p6) partition done."
    echo "********************************************"
fi

#Check for Log_Data Partition
clean_reqd=$(( $clean_bits & $LOGDATA_BIT_POS))
if [ "$clean_reqd" == "$LOGDATA_BIT_POS" ]
then
	## Format the log data partition
	$FAT_FORMAT_CMD -F 32 -n "DATA" ${DRIVE}p7
    echo "DATA(${DRIVE}p7) partition done."
    echo "********************************************"
fi

## Make sure posted writes are cleaned up
sync
sync
echo "Formatting done."

ENDTIME=$(date +%s)
echo "It took $(($ENDTIME - $STARTTIME)) seconds to complete this task..."

echo "********************************************"
echo "Datalogger Format Flash Script is complete."
echo "********************************************"
