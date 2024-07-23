#!/bin/bash

if [[ $EUID -ne 0 ]]
then 
    echo "Run as root."
    exit 1
fi

if ! command -v openssl >/dev/null ; then
    echo "Openssl not found. Is openssl installed?"  
    exit 1
elif ! command -v mokutil >/dev/null ; then
    echo "Mokutil not found. Is mokutil installed?"  
    exit 1
elif ! command -v efibootmgr >/dev/null ; then
    echo "Efibootmgr not found. Is efibootmgr installed?"  
    exit 1
elif ! command -v bsdtar >/dev/null ; then
    echo "Bsdtar not found. Is bsdtar installed?"  
    exit 1
elif ! command -v wget >/dev/null ; then
    echo "Wget not found. Is wget installed?"
    exit 1
fi

release () {
    while read -r os ; do
        echo $os | grep "^ID=" | tr -d ID=
    done < "/etc/os-release"
}

help () {
    echo "grub-mkmok, version 0.2"
    echo "Usage: grub-mkmok [option] ..."
    echo "Options:"
    echo "      -h  (calls help menu)"
    echo "      -s  (install shim to specified EFI directory)"
    echo "      -k  (generate Machine Owner Keys in /root/mok)"
    echo "      -d  (distro name eg: gentoo)"
    exit 0
}

if [ "$#" == 0 ]
then
    help
fi

tmp="/tmp/grub-mkmok"
shimurl="https://kojipkgs.fedoraproject.org//packages/shim/15.8/3/x86_64/shim-x64-15.8-3.x86_64.rpm"

while getopts "hs:k:d:" flag; do
    case $flag in
        h) help;;
        s) shim=${OPTARG};;
        k) machinekeys=${OPTARG};;
        d) distro=${OPTARG};;
        ?) help;;
    esac
done

installshim () {
    if [ $(release) = "1gentoo" ] ; then
        echo "Gentoo detected"
        if [ -e "/usr/share/shim/BOOTX64.EFI" ] ; then
            cp /usr/share/shim/BOOTX64.EFI $shim/EFI/$1/
            cp /usr/share/shim/mmx64.efi $shim/EFI/$1/
            echo "Done."
        else
            echo "Shim not found, install it via."
            echo "emerge sys-boot/shim"
        fi
    elif [ $(release) = "arch" ] ; then
        echo "Archlinux detected"
        if [ -e "/usr/share/shim-signed/shimx64.efi" ] ; then
            cp /usr/share/shim-signed/shimx64.efi $shim/EFI/$1/BOOTX64.EFI
            cp /usr/share/shim/mmx64.efi $shim/EFI/$1/
        else
            echo "Shim not found, install it via."
            echo "AUR package: shim-signed"
        fi
    else
        echo "Supported Distros not detected, to download shim-15.8-3 (2024-03-19) from Fedora manually. [y/n]"
        read -p ":" manlshim
        if [[ "$manlshim" == "y" ]] ; then
            echo "Continuing to download shim-15.8-3 (2024-03-19) from Fedora."
            mkdir -p "$tmp"
            wget -nv -P "$tmp" "$shimurl" --show-progress
            echo "Unpacking."
            bsdtar xf "$tmp/shim-x64-15.8-3.x86_64.rpm" -C "$tmp"
            cp "$tmp/boot/efi/EFI/BOOT/BOOTX64.EFI" "$shim/EFI/$1/"
            cp "$tmp/boot/efi/EFI/fedora/mmx64.efi" "$shim/EFI/$1/"
            rm "$tmp" -r
            echo "Done."
        else 
            echo "Answer No, exiting"
            exit 0
        fi
    fi
    exit 0
}


if [[ ! -z $shim ]] ; then 
    if [ -z $distro ] ; then 
        echo "-d not set, defaulting on ID from os-release"
        echo "Installing shim to $shim/EFI/$(release)"
        installshim $(release)
    else
        echo "Installing shim to $shim/EFI/$distro"
    fi
fi

if [[ -z "$machinekeys" ]] ; then
    echo "-k flag not set."
    exit 2
else 
    echo "-k flag set to $machinekeys."
    if [ -e "$machinekeys/MOK.key" ] ; then 
        echo -e "MOK keys already exist in $machinekeys\nNot overwriting."
        exit 2
    else
        mkdir -p "$machinekeys"
        cd "$machinekeys"
        openssl req -newkey rsa:2048 -nodes -keyout MOK.key -new -x509 -sha256 -subj "/CN=MOK key/" -out MOK.crt
        openssl x509 -outform DER -in MOK.crt -out MOK.cer
        chmod 700 "$machinekeys/MOK.key"
        chmod 700 "$machinekeys/MOK.crt"
        chmod 700 "$machinekeys/MOK.cer"
        echo -e "MOK keys created in $machinekeys"
        exit 0
    fi
fi
