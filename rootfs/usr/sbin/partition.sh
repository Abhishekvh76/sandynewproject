#!/bin/sh
echo "****************************************************"
echo ""
echo "Datalogger Partitioning Script - 07/10/2020         "
echo "                                  by Sunil Adhikari"
echo "****************************************************"


if ! [ $(id -u) = 0 ]; then
    echo "the script needs to be run as root." >&2
    echo "usage:sudo ./partition.sh <Sdcard_device> "
    exit 1
fi

## Declare SD Card device name here
DRIVE=$1

if [ "X$DRIVE" == "X" ]
then
    echo "Usage: sudo ./partition.sh <Sdcard_device> "
    exit -1
fi

STARTTIME=$(date +%s)

##---------Start of variables---------------------##

#EXT Format command
LINUX_FORMAT_CMD="mkfs.ext4"


## Initialize test variable
SUCCESS=1

##----------End of variables-----------------------##

## Kill any partition info that might be there
#dd if=/dev/zero of=$DRIVE bs=4k count=1
#sync
#sync

## Figure out how big the SD Card is in bytes
#SIZE=`fdisk -l $DRIVE | grep Disk | awk 'NR==1 {print $5}'`
#sizeMb=`echo $SIZE/1024/1024 | bc`
#echo "found sd card: $DRIVE size : $SIZE bytes / $sizeMb MB "

## Translate size into segments, which traditional tools call Cylinders. eMMC is not a spinning disk.
## We are basically ignoring what FDISK and SFDISK are reporting because it is not really accurate.
## we are translating this info to something that makes more sense for eMMC.
#CYLINDERS=`echo $SIZE/255/63/512 | bc`

## Check to see if the eMMC partitions have automatically loaded from the old MBR.
## This might have occured during the boot process if the kernel detected a filesystem
## before we killed the MBR. We will need to unmount and kill them by writing 4k zeros to the
## partitions that were found.


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

check_mounted

## Partitioning the eMMC using information gathered.
## Here is where you can add/remove partitions.
## We are building 2 partitions:
##  1. FAT, size = 9 cylinders * 255 heads * 63 sectors * 512 bytes/sec = ~70MB
##  2. EXT3, size = 223 ($CYLINDERS-[9 for fat]) cylinders * 255 heads * 63 sectors * 512 bytes/sec = ~1.7GB
##
## You will need to change the lines ",9,0c0C,*", "10,,,-" to suit your needs.  Adding is similar,
## but you will need to be aware of partition sizes and boundaries.  Use the man page for sfdisk.
echo "Partitioning the sd card..."

########################### PARTITION IMAGE ####################################################

#size is specified in sector= 512bytes  
#helper 1MB = 1024 * 1024 = 1048576 bytes = 2048 sectors
#space reserverd for uboot and environment var : 8MB = 8*1024*1024 bytes= 8388608/512 sectors = 16384 sectors
        #it is same as : 8MB = 8 * 1MB = 8 * 2048 sectors = 16384 sectors

# space for boot partitions = 60 MB = 60 * 2048 = 122880 sectors

#space for app_data partition = 2GB = 2 * 1024 MB = 2 * 1024 * 2048 = 4194304 sectors

#extended partitions

#space for rootfs = 2GB = 2 * 1024 * 2048 = 4194304 sectors

#remaining space is for log_data partition

############################### sfdisk command format ##########################################

# start(no of sectors)(above lines start + above line sectors or (free space for 1st line)),size(sectors),(type of partition)
#16384(free space),122880(boot1 space),0x0C(fat32 type)
#139264(above start + above sector = 61384 + 122880 ),122880(boot2 space),0x0C(fat32 type)
#262144(above start + above sector= 184264 + 122880),4194304(app_data space),0x83 (ext4 type)
#4456448(307144 +4194304 ),(rest everything),E(Extended)
#rememver in extended partition we are skipping 1mb in every partitions
#4417536(450144 + skip (2048)),2097152(rootfs1 space),0x83(linux type(ext4))
#6516736(4417536+2097152+2048),2097152(rootfs2 space),0x83(linux type(ext4))
#8615936(6516736+2097152+2048),(rest everything),0x0C(fat32 type)

sfdisk $DRIVE  << EOF
16384,122880,0x0C
139264,122880,0x0C
262144,4194304,0x83
4456448,,E
,4194304,0x83
,4194304,0x83
,,0x0C
EOF

#4417536,2097152,
#6516736,2097152,0x83
#8615936,,0x0C
#sfdisk -D -H 255 -S 63 -C $CYLINDERS $DRIVE << EOF
#,9,0x0C,*
#,13,0x83,
#,,E,
#;
#,100,0x83,
#,100,0x83,
#,125,0x83,
#,565,0x83,
#;
#EOF

#check_mounted;

## Clean up the dos (FAT) partition as recommended by SFDISK
#dd if=/dev/zero of=${DRIVE}p1 bs=512 count=1

## Make sure posted writes are cleaned up
sync
sync

echo " Partition Script is complete."
echo ""
