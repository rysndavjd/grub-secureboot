#grub-secureboot installer using make

SHELL=/bin/bash
installdir=/usr/local/sbin

all: help

install:
	@echo "Install directory is $(installdir)"
	cp ./grub-mkmok.sh $(installdir)/grub-mkmok
	chmod 555 $(installdir)/grub-mkmok
	cp ./grub-mksecureboot.sh $(installdir)/grub-mksecureboot
	chmod 555 $(installdir)/grub-mksecureboot

uninstall:
	rm $(installdir)/grub-mkmok
	rm $(installdir)/grub-mksecureboot

help: 
	@echo -e "This is makefile for installing grub-mksecureboot and grub-mkmok."
	@echo -e "Make commands:\n	make install\n	make uninstall"
	@echo -e "	make help\n	make clean"
clean:
	@echo "Mate, This is a script not a C program there is nothing to clean"