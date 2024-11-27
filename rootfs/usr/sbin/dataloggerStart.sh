#!/bin/sh

#/****************************************************************************
# * Copyright (C) 2020 by Unizen Technologies				     *
# *                                                                          *
# *                                                    by sunil Adhikari     *
# ****************************************************************************/

#/**
# * @file datalogger starter
# * @author sunil Adhikari <sunilk@unizentechnologies.com>
# * @date june 1 2020
# * @brief Provides datalogger starting Service
# *
# */

#1
#echo "calling otaFinishup.sh"
#sh /usr/bin/appFilesSync.sh
#if [ $? -ne 0 ]; then 
#    echo "app file copy failed please chekc.."
#else
#    echo "ota app files sync ran successfully"
#fi

#2
#start otaFinisher.sh so that if any pending task is there it will be completed
sh /usr/sbin/otaFinishup.sh
if [ $? -ne 0 ]; then 
    echo "ota finishup ran into problem"
else
    echo "ota finishup ran successfully"
fi

#3
# start syncEth1Config.sh to syncup any pending sec eth configuration
sh /usr/sbin/syncEth1Config.sh
if [ $? -ne 0 ]; then
    echo "eth1 config syncup ran into problem"
else
    echo "eth1 config syncup ran successfully"
fi

#4
# insert usb g_msss_storage module to datalogger
#dependencies
modprobe g_mass_storage file=/dev/mmcblk0p7 removable=1
