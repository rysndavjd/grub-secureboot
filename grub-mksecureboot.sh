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
elif ! command -v grub-install >/dev/null; then
    echo "grub-install not found. Is grub installed?" 
    exit 1
elif ! command -v sbsign >/dev/null; then
    echo "sbsign not found. Is sbsigntools installed?" 
    exit 1
fi

if [ "$1" = -h ] ; then
    echo ""
    echo ""
    echo ""
    echo ""
    echo ""
    echo ""
    exit 0
fi

while getopts d:e:m:k:l: flag
do
    case "${flag}" in
        d) distro=${OPTARG};;
        e) efipath=${OPTARG};;
        m) moduletype=${OPTARG};;
        k) mokpath=${OPTARG};;
        l) bootlayout=${OPTARG};;
    esac
done

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

if [[ -z $efipath ]] ; then
    echo "Set -e flag for efi path. Example /efi."
    exit 2
else 
    echo "EFI path set to $efipath."
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

cryptodiskuuid=$(grub-probe /boot -t cryptodisk_uuid)   
cryptodiskcfg () {
    while read -r cryptodisk ; do
        echo $cryptodisk | grep "^GRUB_ENABLE_CRYPTODISK=" | tr -d GRUB_ENABLE_CRYPTODISK=
    done < "/etc/default/grub"
}

#Tells script if the boot layout is full disk encryption or just encrypted root
if [[ -z "$bootlayout" ]] ; then
    echo "-l flag, Please enter boot layout (fde, encroot, standard)"
    echo "Note: I will eventully implemet autodetection."
    exit 2
elif [[ "$bootlayout" == "fde" ]] ; then
    echo "Boot layout is set to full disk encryption."

    if [[ $(cryptodiskcfg) == "y" ]] ; then
        cat <<EOT >> $memdiskdir/grub-bootstrap.cfg
cryptomount -u $cryptodiskuuid
set prefix="(memdisk)"
configfile (crypto0)/grub/grub.cfg
EOT
    else
        echo "GRUB_ENABLE_CRYPTODISK=n or not set in /etc/default/grub"
        exit 2
    fi

elif [[ "$bootlayout" == "encroot" ]] ; then 
    echo "-l Boot layout is set to encrypted root."

    if [[ $(cryptodiskcfg) == "y" ]] ; then
        cat <<EOT >> $memdiskdir/grub-bootstrap.cfg
cryptomount -u $cryptodiskuuid
set prefix="(memdisk)"
configfile (crypto0)/grub/grub.cfg
EOT
    else
        echo "GRUB_ENABLE_CRYPTODISK=n or not set in /etc/default/grub"
        exit 2
    fi

elif [[ "$bootlayout" == "standard" ]] ; then 
    echo "Boot layout is set to standard."
fi


cp -R /usr/share/grub/unicode.pf2 "/$memdiskdir/memdisk/fonts"
mksquashfs "$memdiskdir/memdisk" "$memdiskdir/memdisk.squashfs" -comp gzip >> /dev/null 2>&1
grub-mkimage --config="$memdiskdir/grub-bootstrap.cfg" --directory=/usr/lib/grub/x86_64-efi --output=$installpath/grubx64.efi --sbat=/usr/share/grub/sbat.csv --format=x86_64-efi --memdisk="$memdiskdir/memdisk.squashfs" $grubmodules
sbsign --key $mokpath/MOK.key --cert $mokpath/MOK.crt --output "$installpath/grubx64.efi" "$installpath/grubx64.efi" >> /dev/null 2>&1
clean

echo "Remeber to generate grub.cfg"
echo "Finished"