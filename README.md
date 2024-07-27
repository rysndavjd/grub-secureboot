Grub-mksecureboot is a script that detects partition layout of a system, generates a grub EFI image via grub-mkimage, signs grub image for secureboot and installs grub to EFI partition.

## grub-mksecureboot Usage 
```
Usage: grub-mksecureboot [option] ...
    Options:
          -h  (calls help menu)
          -d  (distro name. eg: gentoo)
          -e  (EFI path. eg: /efi)
          -b  (Boot path. eg: /boot)
          -m  (Modules included in grub, default is all. eg: [all, luks, normal])
          -k  (Machine Owner Key path eg: /root/mok)
          -c  (Put grub.cfg in memdisk)
```
Grub-mkmok is a helper script that sets up initial dependencies for grub-mksecureboot eg: copying of shim to EFI and generation of Machine Owner Keys.
## grub-mkmok Usage 
```
Usage: grub-mksecureboot [option] ...
    Options:
          -h  (calls help menu)
          -s  (install shim to specified EFI directory. eg: /efi)
          -k  (generate Machine Owner Keys in specified directory. eg: /root/mok)
          -d  (distro name. eg: gentoo)
```
## Installation
### Dependencies: 
Gentoo
```
emerge -av sys-boot/shim sys-boot/mokutil sys-boot/efibootmgr dev-libs/openssl app-arch/libarchive net-misc/wget
```
Archlinux (Note: [shim-signed](https://aur.archlinux.org/packages/shim-signed) is required from the AUR.)
```
pacman -S mokutil efibootmgr openssl libarchive wget
```
### Install:
To install run.
```
make install
```
To uninstall run.
```
make uninstall
```
To change install directory from the default of /usr/local/sbin edit the Makefile like so.
```Makefile
installdir=/to/whatever/directory/you/wish
```
