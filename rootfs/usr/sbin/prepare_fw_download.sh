#!/bin/sh

#Create the download folder if it does not exist

DOWNLOAD_PATH=/app_data/ota/download

if [ ! -d $DOWNLOAD_PATH ]
then
    mkdir -p $DOWNLOAD_PATH
fi


