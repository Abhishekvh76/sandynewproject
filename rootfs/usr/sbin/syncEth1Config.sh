#!/bin/sh

#Configuration file reference exposed to user
USR_ETH_CONFIG_PATH=/log_data/configuration/ethernet
REF_ETH_CONFIG_PATH=/app_data/configuration/ethernet
REF_ETH_CONFIG_FILE=/app_data/configuration/ethernet/SecEthernetConfig.txt
USR_ETH_CONFIG_FILE=/log_data/configuration/ethernet/SecEthernetConfig.txt
MASTER_ETH_CONFIG_FILE_PATH=/usr/share/DlEthConfigFiles
ETH_CONFIG_FILE=SecEthernetConfig.txt
#ETH1_NETWORK_CONFIG_PATH=/etc/systemd/network
ETH1_NETWORK_CONFIG_PATH=/etc/systemd/network
ETH1_NETWORK_CONFIG_FILE=eth1.network
ETH1_NETWORK_CONFIG_FILE_BAK=eth1.network.bak

#sed -n '|file /etc|=' $ETH1_NETWORK_CONFIG_PATH/$ETH1_NETWORK_CONFIG_FILE
MD5SUM_USR_ETH_CONFIG=`md5sum $USR_ETH_CONFIG_FILE | cut -d" " -f1`
MD5SUM_REF_ETH_CONFIG=`md5sum $REF_ETH_CONFIG_FILE | cut -d" " -f1`
echo "MD5SUM_USR_ETH_CONFIG: $MD5SUM_USR_ETH_CONFIG"
echo "MD5SUM_REF_ETH_CONFIG: $MD5SUM_REF_ETH_CONFIG"


#if floder doesnot exist create one and copy reference file
if [ ! -d $REF_ETH_CONFIG_PATH ];then
    echo "app data configuration files and folder doesnot exist creating one"
    mkdir -p $REF_ETH_CONFIG_PATH
    chmod 0777 $REF_ETH_CONFIG_PATH
    cp $MASTER_ETH_CONFIG_FILE_PATH/$ETH_CONFIG_FILE $REF_ETH_CONFIG_PATH/$ETH_CONFIG_FILE 
    chmod 0777 $REF_ETH_CONFIG_PATH/$ETH_CONFIG_FILE
fi

if [ ! -d $USR_ETH_CONFIG_PATH ];then
    echo "log data configuration files and folder doesnot exist creating one"
    mkdir -p $USR_ETH_CONFIG_PATH
    chmod 0777 $USR_ETH_CONFIG_PATH
    cp $MASTER_ETH_CONFIG_FILE_PATH/$ETH_CONFIG_FILE $USR_ETH_CONFIG_PATH/$ETH_CONFIG_FILE 
    chmod 0777 $USR_ETH_CONFIG_PATH/$ETH_CONFIG_FILE
fi

#if config file is missing copy one
if [ ! -f $REF_ETH_CONFIG_FILE ];then
    echo "app data configuration file doesnot exist creating one"
    cp $MASTER_ETH_CONFIG_FILE_PATH/$ETH_CONFIG_FILE $REF_ETH_CONFIG_PATH/$ETH_CONFIG_FILE 
    chmod 0777 $REF_ETH_CONFIG_PATH/$ETH_CONFIG_FILE
fi
if [ ! -f $USR_ETH_CONFIG_FILE ];then
    echo "log data configuration file doesnot exist creating one"
    cp $MASTER_ETH_CONFIG_FILE_PATH/$ETH_CONFIG_FILE $USR_ETH_CONFIG_PATH/$ETH_CONFIG_FILE 
    chmod 0777 $USR_ETH_CONFIG_PATH/$ETH_CONFIG_FILE
fi

sync
sync

#if files are not changed exit out
if [ "$MD5SUM_USR_ETH_CONFIG" == "$MD5SUM_REF_ETH_CONFIG" ]
then
    echo "Ethernet config file is same exiting... "
    exit 0
fi

#if file is changed change ethernet config file also
SIP_ADDRESS=`awk '!/#/ {print}' $USR_ETH_CONFIG_FILE | grep ip_address | cut -d":" -f2`
SPORT_NUMBER=`awk '!/#/ {print}' $USR_ETH_CONFIG_FILE | grep port_number | cut -d":" -f2`
SSUBNET_MASK=`awk '!/#/ {print}' $USR_ETH_CONFIG_FILE | grep subnet_mask | cut -d":" -f2`
PORT_NUMBER=`printf '%d' "$SPORT_NUMBER"` 
SUBNET_MASK=`printf '%d' "$SSUBNET_MASK"` 
echo "IP_ADDRESS: $SIP_ADDRESS PORT_NUMBER:$PORT_NUMBER SUBNET_MASK:$SUBNET_MASK"


#validate ip address
IP_PART=`echo $SIP_ADDRESS | awk '{split($0,a,".");print a[1],a[2],a[3],a[4]}'`
j=0
#echo "legth is : "${#IP_PART[@]}""
#for i in ${IP_PART[@]};
#do
#    echo $i
#    #var[j]=$i
#    ((++j))
#    val=`expr $i + 0`
#    if [[ $val -lt 0 || $val -gt 255  ]];then
#        echo "ip address is incorrect check field: $j"
#        exit 1
#    fi
#done
#echo "j : $j"
#if [ $j -ne 4 ];then
#    echo "ip addrss is not correct more than 4 fields"
#    exit 1
#fi

#validate port number
if [[ $PORT_NUMBER -ge 65535 || $PORT_NUMBER -le 1024 ]];then
    echo "port number is incorrect"
    exit 0
fi

#validate subnet mask
if [[ $SUBNET_MASK -ge 32 || $SUBNET_MASK -le 1 ]];then
    echo "Subnet mask is incorrect"
    exit 0
fi

echo "everything is correct using user provided ethernet configuration"

#construct ip and subnet mask string
ETH1_IP="$SIP_ADDRESS\/$SUBNET_MASK"
echo "ETH1_IP: $ETH1_IP"

#copy old eth1.network for backup
cp $ETH1_NETWORK_CONFIG_PATH/$ETH1_NETWORK_CONFIG_FILE  $REF_ETH_CONFIG_PATH/$ETH1_NETWORK_CONFIG_FILE_BAK
IP_LINE_NO=`awk '/Address/ {print NR}' $ETH1_NETWORK_CONFIG_PATH/$ETH1_NETWORK_CONFIG_FILE`
CHANGE_CMD="sed -i '"${IP_LINE_NO}"s/.*/Address=$ETH1_IP/' $ETH1_NETWORK_CONFIG_PATH/$ETH1_NETWORK_CONFIG_FILE"
cmd=`echo $CHANGE_CMD`
eval $cmd
if [ $? -eq 0 ];then
    echo "ip changed successfully"
    cp $USR_ETH_CONFIG_FILE $REF_ETH_CONFIG_FILE

    #restart systemd-networkd
    systemctl restart systemd-networkd
    if [ $? -eq 0 ];then
        echo "ethernet ip updated successfully"
        sync 
        sync

        exit 0
    fi
fi
#$CHANGE_CMD
#echo "change cmd: $CHANGE_CMD"

