# Copyright 2024 rysndavjd
# Distributed under the terms of the GNU General Public License v2

include config.mk

all: install

clean:
	rm -f grub-secureboot-${VERSION}.tar.gz

release: clean
	mkdir -p grub-secureboot-${VERSION}
	cp -R LICENSE Makefile README.md config.mk \
		grub-mkmok.sh grub-mksecureboot.sh grub-secureboot-${VERSION}
	tar -cf grub-secureboot-${VERSION}.tar grub-secureboot-${VERSION}
	gzip grub-secureboot-${VERSION}.tar
	rm -rf grub-secureboot-${VERSION}

install:
	mkdir -p ${DESTDIR}${PREFIX}/bin
	cp -f grub-mksecureboot.sh ${DESTDIR}${PREFIX}/bin/grub-mksecureboot
	cp -f grub-mkmok.sh ${DESTDIR}${PREFIX}/bin/grub-mkmok
	chmod 755 ${DESTDIR}${PREFIX}/bin/grub-mksecureboot
	chmod 755 ${DESTDIR}${PREFIX}/bin/grub-mkmok

uninstall:
	rm -fr ${DESTDIR}${PREFIX}/bin/grub-mksecureboot \
		${DESTDIR}${PREFIX}/bin/grub-mkmok 

.PHONY: all clean release install uninstall
