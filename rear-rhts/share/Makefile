
FILES := failurestrings falsestrings

install:
	mkdir -p $(DESTDIR)/usr/share/rear-rhts
	for file in $(FILES); do install -m 644 $$file $(DESTDIR)/usr/share/rear-rhts; done
	#ln -s $(DESTDIR)/usr/share/rear-rhts $(DESTDIR)/usr/share/rhts

