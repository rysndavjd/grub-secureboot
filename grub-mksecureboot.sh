#!/bin/bash
set -e

if [[ $EUID -ne 0 ]]
then 
    echo "Run as root."
    exit 1
fi

trap ctrl_c INT

ctrl_c () {
    echo "Ctrl + C happened"
    rm /tmp/memdiskdir -r
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

while getopts d:e:m:k: flag
do
    case "${flag}" in
        d) distro=${OPTARG};;
        e) efipath=${OPTARG};;
        m) moduletype=${OPTARG};;
        k) mokpath=${OPTARG};;
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
    grubmodules="all_video boot btrfs cat chain configfile echo efifwsetup efinet ext2 fat font gettext gfxmenu gfxterm gfxterm_background gzio halt help hfsplus iso9660 jpeg keystatus loadenv loopback linux ls lsefi lsefimmap lsefisystab lssal memdisk minicmd normal ntfs part_apple part_msdos part_gpt password_pbkdf2 png probe reboot regexp search search_fs_uuid search_fs_file search_label sleep smbios squash4 test true video xfs play cpuid tpm cryptodisk gcry_arcfour gcry_blowfish gcry_camellia gcry_cast5 gcry_crc gcry_des gcry_dsa gcry_idea gcry_md4 gcry_md5 gcry_rfc2268 gcry_rijndael gcry_rmd160 gcry_rsa gcry_seed gcry_serpent gcry_sha1 gcry_sha256 gcry_sha512 gcry_tiger gcry_twofish gcry_whirlpool luks lvm mdraid09 mdraid1x raid5rec raid6rec http tftp"
elif [ "$moduletype" == "luks" ] ; then
    grubmodules="all_video boot btrfs cat chain configfile echo efifwsetup efinet ext2 fat font gettext gfxmenu gfxterm gfxterm_background gzio halt help hfsplus iso9660 jpeg keystatus loadenv loopback linux ls lsefi lsefimmap lsefisystab lssal memdisk minicmd normal ntfs part_apple part_msdos part_gpt password_pbkdf2 png probe reboot regexp search search_fs_uuid search_fs_file search_label sleep smbios squash4 test true video xfs play cpuid tpm cryptodisk gcry_arcfour gcry_blowfish gcry_camellia gcry_cast5 gcry_crc gcry_des gcry_dsa gcry_idea gcry_md4 gcry_md5 gcry_rfc2268 gcry_rijndael gcry_rmd160 gcry_rsa gcry_seed gcry_serpent gcry_sha1 gcry_sha256 gcry_sha512 gcry_tiger gcry_twofish gcry_whirlpool luks lvm mdraid09 mdraid1x raid5rec raid6rec"
elif [ "$moduletype" == "normal" ] ; then
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
memdiskdir="/tmp/memdiskdir"
memdiskpath="$memdiskdir/memdisk/"
mkdir -p "$memdiskpath"
mkdir -p $installpath

grub-install --no-nvram --efi-directory=$efipath >> /dev/null
rm -f $installpath/grubx64.efi

grubcryptodisk () {
    while read -r cryptodisk ; do
        echo $cryptodisk | grep "^GRUB_ENABLE_CRYPTODISK=" | tr -d GRUB_ENABLE_CRYPTODISK=
    done < "/etc/default/grub"
}

if [[ $(grubcryptodisk) == "y" ]] ; then
    cat "/boot/grub/x86_64-efi/load.cfg" > "$memdiskdir/grub-bootstrap.cfg"
    cat >> "$memdiskdir/grub-bootstrap.cfg" <<< "set prefix=\"(memdisk)\""
else
    echo "GRUB_ENABLE_CRYPTODISK=n or not in /etc/default/grub"
    touch "$memdiskdir/grub-bootstrap.cfg"
    cat >> "$memdiskdir/grub-bootstrap.cfg" <<< "set prefix=\"(memdisk)\""
fi

cp -R /boot/grub/fonts /boot/grub/grub* "$memdiskpath/"
mksquashfs "$memdiskdir/memdisk" "$memdiskdir/memdisk.squashfs" -comp xz >> /dev/null 2>&1
grub-mkimage --config="$memdiskdir/grub-bootstrap.cfg" --directory=/usr/lib/grub/x86_64-efi --output=$installpath/grubx64.efi --sbat=/usr/share/grub/sbat.csv --format=x86_64-efi --memdisk="$memdiskdir/memdisk.squashfs" $grubmodules
sbsign --key $mokpath/MOK.key --cert $mokpath/MOK.crt --output "$installpath/grubx64.efi" "$installpath/grubx64.efi" >> /dev/null 2>&1
rm $memdiskdir -r

echo "Finished"