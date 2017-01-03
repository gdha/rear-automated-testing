
name=rear-rhts
specfile=$(name).spec
version := $(shell awk 'BEGIN { FS=":" } /^Version:/ { print $$2}' $(specfile) | awk '{print $$1}' )

all: dist rpm

dist: $(name)-$(version).tar.gz

$(name)-$(version).tar.gz:
	@echo "Building $(name)-$(version).tar.gz archive"
	tar zcf /tmp/$(name)-$(version).tar.gz \
	--transform='s,^\.,$(name)-$(version),S' .

rpm: $(specfile) $(name)-$(version).tar.gz
	rpmbuild -v -tb --clean \
		/tmp/$(name)-$(version).tar.gz

clean:
	-rm -f /tmp/$(name)-$(version).tar.gz
