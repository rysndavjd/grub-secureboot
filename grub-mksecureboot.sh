#!/bin/bash
set -e

if [[ $EUID -ne 0 ]]
then 
    echo "Run as root."
    exit 1
fi

tmp="/tmp/grub-secureboot"

trap clean INT

clean () {
    rm $tmp -r
}

if ! command -v mksquashfs >/dev/null; then
    echo "mksquashfs not found. Is squashfs-tools installed?" 
    exit 1
elif ! command -v grub-mkimage >/dev/null; then
    echo "grub-mkimage not found. Is grub installed?" 
    exit 1
elif ! command -v sbsign >/dev/null; then
    echo "sbsign not found. Is sbsigntools installed?" 
    exit 1
fi

help () {
    echo "grub-mksecureboot, version 0.2"
    echo "Usage: grub-mksecureboot [option] ..."
    echo "Options:"
    echo "      -h  (calls help menu)"
    echo "      -d  (distro name eg: gentoo)"
    echo "      -e  (EFI path eg: /efi)"
    echo "      -b  (Boot path eg: /boot)"
    echo "      -m  (Modules included in grub, default all is selected [all, luks, normal])"
    echo "      -k  (Machine Owner Key path, defaults to /root/mok)"
    exit 0
}

while getopts hd:e:b:m:k: flag; do
    case "${flag}" in
        h) help;;
        d) distro=${OPTARG};;
        e) efipath=${OPTARG};;
        b) bootpath=${OPTARG};;
        m) moduletype=${OPTARG};;
        k) mokpath=${OPTARG};;
        ?) help;;
    esac
done

if [[ -z $efipath ]] ; then
    echo "Set -e flag, do -h for help"
    exit 2
else 
    echo "EFI path set to $efipath."
fi

release () {
    while read -r os ; do
        echo $os | grep "^ID=" | tr -d ID=
    done < "/etc/os-release"
}

if [[ -z $distro ]] ; then
    echo "-d flag not set using ID from os-release, $(release)."
    distro=$(release)
else
    echo "distro set to $distro"
fi

if [[ -z $bootpath ]] ; then
    echo "Set -b flag, do -h for help"
    exit 2
else 
    echo "Boot path set to $bootpath."
fi

#sets grubmodules variable
if [[ "$moduletype" == "all" || -z "$moduletype" ]] ; then
    echo "Grub modules set to all."
    grubmodules="all_video boot btrfs cat chain configfile echo efifwsetup efinet ext2 fat font gettext gfxmenu gfxterm gfxterm_background gzio halt help hfsplus iso9660 jpeg keystatus loadenv loopback linux ls lsefi lsefimmap lsefisystab lssal memdisk minicmd normal ntfs part_apple part_msdos part_gpt password_pbkdf2 png probe reboot regexp search search_fs_uuid search_fs_file search_label sleep smbios squash4 test true video xfs play cpuid tpm cryptodisk gcry_arcfour gcry_blowfish gcry_camellia gcry_cast5 gcry_crc gcry_des gcry_dsa gcry_idea gcry_md4 gcry_md5 gcry_rfc2268 gcry_rijndael gcry_rmd160 gcry_rsa gcry_seed gcry_serpent gcry_sha1 gcry_sha256 gcry_sha512 gcry_tiger gcry_twofish gcry_whirlpool luks lvm mdraid09 mdraid1x raid5rec raid6rec http tftp"
elif [ "$moduletype" == "luks" ] ; then
    echo "Grub modules set to luks."
    grubmodules="all_video boot btrfs cat chain configfile echo efifwsetup efinet ext2 fat font gettext gfxmenu gfxterm gfxterm_background gzio halt help hfsplus iso9660 jpeg keystatus loadenv loopback linux ls lsefi lsefimmap lsefisystab lssal memdisk minicmd normal ntfs part_apple part_msdos part_gpt password_pbkdf2 png probe reboot regexp search search_fs_uuid search_fs_file search_label sleep smbios squash4 test true video xfs play cpuid tpm cryptodisk gcry_arcfour gcry_blowfish gcry_camellia gcry_cast5 gcry_crc gcry_des gcry_dsa gcry_idea gcry_md4 gcry_md5 gcry_rfc2268 gcry_rijndael gcry_rmd160 gcry_rsa gcry_seed gcry_serpent gcry_sha1 gcry_sha256 gcry_sha512 gcry_tiger gcry_twofish gcry_whirlpool luks lvm mdraid09 mdraid1x raid5rec raid6rec"
elif [ "$moduletype" == "normal" ] ; then
    echo "Grub modules set to normal."
    grubmodules="all_video boot btrfs cat chain configfile echo efifwsetup efinet ext2 fat font gettext gfxmenu gfxterm gfxterm_background gzio halt help hfsplus iso9660 jpeg keystatus loadenv loopback linux ls lsefi lsefimmap lsefisystab lssal memdisk minicmd normal ntfs part_apple part_msdos part_gpt password_pbkdf2 png probe reboot regexp search search_fs_uuid search_fs_file search_label sleep smbios squash4 test true video xfs play cpuid tpm lvm mdraid09 mdraid1x raid5rec raid6rec"
else
    echo "Enter valid option for -m (all,luks,normal)"
    exit 2
fi 

#Checks mok path if mok keys exist
if [[ -z "$mokpath" ]] ; then
    echo "-k flag not set, defaulting to /root/mok."
    mokpath="/root/mok"
    if [ ! -e "$mokpath/MOK.key" ] ; then
        echo -e "MOK key does not exist.\nRun grub-mkmok to generate mok keys."
    fi
else 
    #echo "-k flag set to $mokpath."
    if [ ! -e "$mokpath/MOK.key" ] ; then
        echo -e "MOK key does not exist.\nMake sure mok keys are in format MOK.(key,crt,cer)."
    fi
fi

installpath=$efipath/EFI/$distro
memdiskdir="$tmp/memdiskdir"
mkdir -p $installpath
mkdir -p $tmp
mkdir -p $memdiskdir/memdisk/fonts

checklayout () {
    cryptodiskuuidboot=$(grub-probe $bootpath -t cryptodisk_uuid)
    bootuuid=$(grub-probe -t fs_uuid $bootpath)
    efiuuid=$(grub-probe -t fs_uuid $efipath)
    rootuuid=$(grub-probe -t fs_uuid /)

    cryptodisk () {
        grub-probe -t drive $1 | grep cryptouuid >> /dev/null 2>&1
        return $?
    }

    #check if / is encrypted
    if cryptodisk / ; then
        #check if boot is actual on root that is encrypted as one partition via its uuid
        if [[ $bootuuid == $rootuuid ]] ; then
            #Here assume disk layout is 
            #efi - unencrypted
            #root - encrypted with /boot on it
            cat <<EOT >> $memdiskdir/grub-bootstrap.cfg
cryptomount -u $cryptodiskuuidboot
set prefix="(memdisk)"
configfile (crypto0)/boot/grub/grub.cfg
EOT
            echo "Layout detected: EFI + encrypted root with boot."
        #boot is separate partition as uuid not equal
        elif [[ $bootuuid != $rootuuid ]] ; then
            #Here assume disk layout is 
            #efi - unencrypted
            #boot - encrypted
            #root - encrypted
            cat <<EOT >> $memdiskdir/grub-bootstrap.cfg
cryptomount -u $cryptodiskuuidboot
set prefix="(memdisk)"
configfile (crypto0)/grub/grub.cfg
EOT
            echo "Layout detected: EFI + encrypted boot + encrypted root."
        fi
    #/ not encrypted, standard install
    else
        #check if boot is actual on root as one partition
        if [[ $bootuuid == $rootuuid ]] ; then
            #Here assume disk layout is 
            #efi - unencrypted
            #root - unencrypted with /boot on it
            cat <<EOT >> $memdiskdir/grub-bootstrap.cfg
set prefix="(memdisk)"
search.fs_uuid $bootuuid root
configfile (\$root)/boot/grub/grub.cfg
EOT
            echo "Layout detected: EFI + unencrypted root with boot"
        elif [[ $bootuuid != $rootuuid ]] ; then
            #Here assume disk layout is 
            #efi - unencrypted
            #boot - unencrypted
            #root - unencrypted
            #or 
            #efi + boot - unencrypted
            #root - unencrypted
            cat <<EOT >> $memdiskdir/grub-bootstrap.cfg
set prefix="(memdisk)"
search.fs_uuid $bootuuid root
configfile (\$root)/grub/grub.cfg
EOT
            echo "Layout detected: EFI + unencrypted boot + unencrypted root."
        fi
    fi
}

makegrub () {
cp -R /usr/share/grub/unicode.pf2 "/$memdiskdir/memdisk/fonts"
mksquashfs "$memdiskdir/memdisk" "$memdiskdir/memdisk.squashfs" -comp gzip >> /dev/null 2>&1
grub-mkimage --config="$memdiskdir/grub-bootstrap.cfg" --directory=/usr/lib/grub/x86_64-efi --output=$installpath/grubx64.efi --sbat=/usr/share/grub/sbat.csv --format=x86_64-efi --memdisk="$memdiskdir/memdisk.squashfs" $grubmodules
sbsign --key $mokpath/MOK.key --cert $mokpath/MOK.crt --output "$installpath/grubx64.efi" "$installpath/grubx64.efi" >> /dev/null 2>&1
clean
echo "Grub EFI image generated, signed and installed at "$installpath/grubx64.efi""
}

checklayout
makegrub
echo "Remember to generate grub.cfg at /boot/grub/grub.cfg"
echo "Finished"
