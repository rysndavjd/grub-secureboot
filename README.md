# grub-secureboot
grub-secureboot is a script that detects partition layout of a system, generates a grub EFI image via grub-mkimage, signs grub image for secureboot and installs grub to EFI partition.

## Usage 
```
Usage: grub-mksecureboot [option] ...
    Options:
          -h  (calls help menu)
          -d  (distro name eg: gentoo)
          -e  (EFI path eg: /efi)
          -b  (Boot path eg: /boot)
          -m  (Modules included in grub, default all is selected [all, luks, normal])
          -k  (Machine Owner Key path, defaults to /root/mok)
```
## Installation
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
