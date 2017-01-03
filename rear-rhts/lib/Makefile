FILES := rhts-make.include

install:
	mkdir -p $(DESTDIR)/usr/share/rear-rhts/lib
	for file in $(FILES); do install -m 755 $$file $(DESTDIR)/usr/share/rear-rhts/lib; done
