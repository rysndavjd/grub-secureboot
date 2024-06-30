#!/bin/sh
set -e

if [[ $EUID -ne 0 ]]
then 
    echo "Run as root."
    exit 1
fi

#Your MOK (Machine Owner Key) path
MOKkeypath="/root/mok/"
#path to current grub efi image
grubefi="/efi/EFI/BOOT/grubx64.efi"
#grub efi directory
grubefipath="/efi/"
#Will use at later iteration of this script
#distro="gentoo"
#Point other grub config if its differnet
grubcfg="/boot/grub/grub.cfg"
#Memdisk work directory
memdiskdir="./memdiskdir"
#grub modules by default it will install all modules for x86_64-efi
grubmodules="all_video boot btrfs cat chain configfile echo efifwsetup efinet ext2 fat font gettext gfxmenu gfxterm gfxterm_background gzio halt help hfsplus iso9660 jpeg keystatus loadenv loopback linux ls lsefi lsefimmap lsefisystab lssal memdisk minicmd normal ntfs part_apple part_msdos part_gpt password_pbkdf2 png probe reboot regexp search search_fs_uuid search_fs_file search_label sleep smbios squash4 test true video xfs play cpuid tpm cryptodisk gcry_arcfour gcry_blowfish gcry_camellia gcry_cast5 gcry_crc gcry_des gcry_dsa gcry_idea gcry_md4 gcry_md5 gcry_rfc2268 gcry_rijndael gcry_rmd160 gcry_rsa gcry_seed gcry_serpent gcry_sha1 gcry_sha256 gcry_sha512 gcry_tiger gcry_twofish gcry_whirlpool luks"

#removes old files in memdiskdir to generate new image
rm ./memdiskdir/* -r

#Updates grub files to copy into memdisk
grub-install --no-nvram --efi-directory=$grubefipath

memdiskpath="$memdiskdir/memdisk/"
mkdir -p "$memdiskpath"
#Gets grub preload config to add to grub image
cat "/boot/grub/x86_64-efi/load.cfg" > "$memdiskdir/grub-bootstrap.cfg"
#Set grub prefix to to memdisk after disk is decrypted
cat >> "$memdiskdir/grub-bootstrap.cfg" << EOF
set prefix="(memdisk)"
EOF

#Copies fonts, grubenv and grub.cfg into memdisk folder
cp -R /boot/grub/fonts /boot/grub/grub* "$memdiskpath/"
#makes memdisk to embedded into the grub image
mksquashfs "$memdiskdir/memdisk" "$memdiskdir/memdisk.squashfs" -comp xz
#Makes grub efi image with embedded memdisk, sbat for secureboot and all modules in $grubmodules
grub-mkimage --config="$memdiskdir/grub-bootstrap.cfg" --directory=/usr/lib/grub/x86_64-efi --output=./grubx64.efi --sbat=/usr/share/grub/sbat.csv --format=x86_64-efi --memdisk="$memdiskdir/memdisk.squashfs" $grubmodules
#moves finisged grub image to efi directory
mv ./grubx64.efi "$grubefi"
#signs the grub image for shim 
sbsign --key $MOKkeypath/MOK.key --cert $MOKkeypath/MOK.crt --output "$grubefi" "$grubefi"
