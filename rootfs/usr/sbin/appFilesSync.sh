#!/bin/sh

#/****************************************************************************
# * Copyright (C) 2020 by Unizen Technologies				     *
# *                                                                          *
# *                                                                          *
# ****************************************************************************/

#/**
# * @file service to syncup files for application
# * @author sunil Adhikari <sunilk@unizentechnologies.com>
# * @date june 1 2020
# * @brief copies application files to app_data partition so that they will be preserved during successive ota update
# *
# */

echo "################################################################################################"
echo "		         Application files syncup service"
echo "                                           by sunil Adhikari"
echo "################################################################################################"



APP_FILES_PATH=/app_data/app_files
#status file holding status of app files
APP_FILES_STATUS_FILE=Status.txt
#sources 
APP_FILES_SRC_PATH=/usr/share/DlAppFiles
DLINFO_FILE_NAME=Dl_Info.txt
MQTT_SERVER_INFO_FILE_NAME=Mqtt_Server_Info.txt


if [ ! -d $APP_FILES_PATH ]; then 
    echo "datalogger NIE application files doesnt exist creating directoty.."
    mkdir -p $APP_FILES_PATH
fi

if [ ! -f $APP_FILES_PATH/$APP_FILES_STATUS_FILE ];then
    echo "app status file doesnot exits creating one..."
    touch $APP_FILES_PATH/$APP_FILES_STATUS_FILE
    echo "Filename=presentStatus" > $APP_FILES_PATH/$APP_FILES_STATUS_FILE
else
dlinfoFileStatus=`cat $APP_FILES_PATH/$APP_FILES_STATUS_FILE | grep $DLINFO_FILE_NAME | cut -d"=" -f2`
mqttServerInfoFileStatus=`cat $APP_FILES_PATH/$APP_FILES_STATUS_FILE | grep $MQTT_SERVER_INFO_FILE_NAME | cut -d"=" -f2`

if (("$dlinfoFileStatus" == "1" & "$mqttServerInfoFileStatus" == "1"));then
    echo "every files are upto date.."
    exit 0
fi
fi

#copy dlinfo file to app_data partition
if [ "$dlinfoFileStatus" != "1" ];then
    echo "$DLINFO_FILE_NAME doesnot exist copying one.."
    cp $APP_FILES_SRC_PATH/$DLINFO_FILE_NAME $APP_FILES_PATH
    echo "$DLINFO_FILE_NAME=1" >> $APP_FILES_PATH/$APP_FILES_STATUS_FILE
fi

#copy mqttserverinfo file to app_data partition
if [ "$mqttServerInfoFileStatus" != "1" ];then
    echo "$MQTT_SERVER_INFO_FILE_NAME doesnot exist copying one.."
    cp $APP_FILES_SRC_PATH/$MQTT_SERVER_INFO_FILE_NAME $APP_FILES_PATH
    echo "$MQTT_SERVER_INFO_FILE_NAME=1" >> $APP_FILES_PATH/$APP_FILES_STATUS_FILE
fi



