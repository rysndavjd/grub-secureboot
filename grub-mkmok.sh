#!/bin/bash

if [[ $EUID -ne 0 ]]
then 
    echo "Run as root."
    exit 1
fi

if ! command openssl 2>/dev/null; then
    echo "Openssl not found. Is it installed?"  
fi

if [ -e "/root/mok/MOK.key" ]
then 
    echo -e "MOK keys already exist in /root/mok\nNot overwriting."
    exit 2
else
    mkdir -p /root/mok
    cd /root/mok
    openssl req -newkey rsa:2048 -nodes -keyout MOK.key -new -x509 -sha256 -subj "/CN=MOK key/" -out MOK.crt
    openssl x509 -outform DER -in MOK.crt -out MOK.cer
    chmod 700 /root/mok -R
    echo -e "MOK keys created in /root/mok"
    exit 0
fi