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

OTA_PATH=/app_data/ota
#ota status file holding status of ota update
OTA_STATUS_FILE=$OTA_PATH/Status.txt

#datalogger info file 
USER_DLINFO_PATH=/log_data/Device_Details
USER_DLINFO_FILE=$USER_DLINFO_PATH/Device_Info.txt
SOFTWARE_VERSION_FILE=/app_data/ota/VERSION.txt


echo "################################################################################################"
echo "		         OTA Finisher Version 1.0"
echo "                                           by sunil Adhikari"
echo "################################################################################################"


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



upgrade_bits=`fw_printenv upgrade_bits | cut -d"=" -f2`
echo "upgrade_bits is : $upgrade_bits"

if [ "$upgrade_bits" != "0" ]; then
    echo "upgrade bits present ota completion was pending"

    #read Status.txt file and extract expected rootpart and bootpart
    if [ ! -f $OTA_STATUS_FILE  ]; then
        echo "Ota Status file doesnot exitst exitting out"
        exit 0
    fi
    expected_bootpart=`cat $OTA_STATUS_FILE | grep expected_bootpart | cut -d":" -f2`
    expected_rootpart=`cat $OTA_STATUS_FILE | grep expected_rootpart | cut -d":" -f2`

    #read current bootpart and current rootpart 
    current_bootpart=`fw_printenv bootpart | cut -d"=" -f2`
    current_rootpart=`fw_printenv rootpart | cut -d"=" -f2`

echo "expected_bootpart=$expected_bootpart expected_rootpart=$expected_rootpart current_bootpart=$current_bootpart current_rootpart=$current_rootpart"
echo "################################################################################################"

    # compare them
    if [[ "$expected_bootpart" == "$current_bootpart" && "$expected_rootpart" == "$current_rootpart" ]];then
        echo "rootpart and bootpart mached"

            #finishup ota update ota retry and update bits to 0
            fw_setenv upgrade_bits 0
            fw_setenv otaRetry 0
            sed -i  '3s/.*/ota_completed:1/' $OTA_STATUS_FILE
            echo "resopnse_pending:1" >> $OTA_STATUS_FILE
            echo "Verifying if upgrade is completed"
            test_upgrade_bits=`fw_printenv upgrade_bits | cut -d"=" -f2`
            if [ $test_upgrade_bits -ne 0 ] ; then
                fw_setenv upgrade_bits 0
                fw_setenv otaRetry 0
            else
                echo "all matched now can say ota completed"
            fi
        else
            fw_setenv upgrade_bits 0
            fw_setenv otaRetry 0
            echo "resopnse_pending:1" >> $OTA_STATUS_FILE
            echo "ota upgrade failed"
            echo "sorry better luck next time"
            test_upgrade_bits=`fw_printenv upgrade_bits | cut -d"=" -f2`
            if [ $test_upgrade_bits -ne 0 ] ; then
                fw_setenv upgrade_bits 0
                fw_setenv otaRetry 0
            fi

    fi

else
    # write dlinfo file currently device id and software version
    if [ ! -d $USER_DLINFO_PATH ];then
        echo "$USER_DLINFO_PATH folder doesnot exists creating one..."
        mkdir -p $USER_DLINFO_PATH
    fi
    #read datalogger id and write
    echo "DeviceId:$DLID" > $USER_DLINFO_FILE
    # read software version and wtire
    if [ -f $SOFTWARE_VERSION_FILE ]; then
        echo "Reading ota version and updating "
        swVersion=`cat $SOFTWARE_VERSION_FILE | grep VERSION | cut -d":" -f2`
        echo "Software_Version:$swVersion" >> $USER_DLINFO_FILE
    else
        echo "updating Factory Version as software version"
        echo "Software_Version:Factory version" >> $USER_DLINFO_FILE
    fi
    echo "Software version is written"



fi

