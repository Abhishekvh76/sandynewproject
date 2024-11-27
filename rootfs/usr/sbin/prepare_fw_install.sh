#!/bin/sh

#Version 1.0

echo "-------------------------------------------"
echo "Running Installation Script V1.0"
echo "-------------------------------------------"

DOWNLOAD_FILE=$1
OTA_PATH=/ota
DOWNLOAD_PATH=/app_data/ota/download
EXTRACT_CMD="unzip"
EXTRACT_ARGS=""
EXTRACT_PATH_ARGS="-d"
EXTRACT_PATH=$DOWNLOAD_PATH/extract
#UPGRADE_MANAGER="ota_upgrade.sh"
UPGRADE_MANAGER=/usr/sbin/ota_upgrade.sh
DLINFO_FILE=/app_data/app_files/Dl_Info.txt

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
        break
        #return $DLID
        #echo "datalogger id matched $value $DLID"
    fi
done
}

error()
{
        echo "-------------------------------------------"
        echo "Firmware Upgrade Error "
        echo "-------------------------------------------"
        sync
        sleep 5
#        reboot
}


#read datalogger id 
get_dlid
echo "datalogger id is : $DLID"
OTA_TOPIC=$DLID/Ota

#Remove any previous extractions
rm -rf $EXTRACT_PATH
mkdir -p $EXTRACT_PATH


#extract the file
#send mqtt packet
timestamp=`date '+%s'`
mqttSendMessage $OTA_TOPIC "{\"Dl_Id\": \"$DLID\", \"Time\": $timestamp, \"Pkt_Type\": \"OtaStatus\", \"Status\": \"Extracting Downloaded packages\"}" $OTA_TOPIC 1 1
echo "Extracting the files downloaded"
$EXTRACT_CMD $EXTRACT_ARGS $DOWNLOAD_FILE $EXTRACT_PATH_ARGS $EXTRACT_PATH

if [ $? -ne 0 ]
then
#send mqtt packet
timestamp=`date '+%s'`
mqttSendMessage $OTA_TOPIC "{\"Dl_Id\": \"$DLID\", \"Time\": $timestamp, \"Pkt_Type\": \"OtaStatus\", \"Status\": \"Firmware Extraction error\"}" $OTA_TOPIC 1 1
    echo "-------------------------------------------"
    echo "Firmware Extract Error, Wrong File"
    echo "-------------------------------------------"
    error
    exit 7
fi

#Execute the upgrade script from the extract path and the Script will take control
echo "Running upgrade manager"
pwd
chmod +x $UPGRADE_MANAGER
$UPGRADE_MANAGER

if [ $? -ne 0 ]
then
#send mqtt packet
timestamp=`date '+%s'`
mqttSendMessage $OTA_TOPIC "{\"Dl_Id\": \"$DLID\", \"Time\": $timestamp, \"Pkt_Type\": \"OtaStatus\", \"Status\": \"Error while running ota_upgrade.sh \"}" $OTA_TOPIC 1 1
    echo "-------------------------------------------"
    echo "Firmware Update Execution Error"
    echo "-------------------------------------------"
    error
    exit -8
fi

echo "-------------------------------------------"
echo "Firmware Update Complete, Rebooting"
echo "-------------------------------------------"
#reboot

