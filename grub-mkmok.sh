#!/bin/sh

if [[ $EUID -ne 0 ]]
then 
    echo "Run as root."
    exit 1
fi

openssl req -newkey rsa:2048 -nodes -keyout MOK.key -new -x509 -sha256 -subj "/CN=MOK key/" -out MOK.crt
openssl x509 -outform DER -in MOK.crt -out MOK.cer

mkdir -p /root/mok
mv -n ./MOK.crt ./MOK.key ./MOK.cer /root/mok
if [[ $? == 1 ]]
then 
    echo "mok keys already exist not overwriting"
    rm ./MOK.crt ./MOK.key ./MOK.cer
else
    chmod 700 /root/mok -R
    echo "Mok keys created and moved to /root/mok/"
fi 