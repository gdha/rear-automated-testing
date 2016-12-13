
FILES := failurestrings falsestrings

install:
	mkdir -p $(DESTDIR)/usr/share/rhts
	for file in $(FILES); do install -m 644 $$file $(DESTDIR)/usr/share/rhts; done

