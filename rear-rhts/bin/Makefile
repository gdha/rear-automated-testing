# "Public" scripts, installed to /usr/bin:
PUBLIC_SHELL_SCRIPTS := rhts-run-package rhts-backup rhts-restore \
         rhts-environment.sh rhts-reboot rhts-report-result rhts-run-simple-test \
         rhts-system-info rhts-test-runner.sh rhts-extend
PUBLIC_PYTHON_SCRIPTS := rhts-lint rhts-abort rhts-db-submit-result \
         rhts-recipe-sync-block rhts-recipe-sync-set rhts-sync-block rhts-sync-set \
         rhts-submit-log rhts-test-checkin rhts-test-update rhts-power

# "Private" scripts, intended to be invoked by the Makefile, rather than directly
# We install these to /usr/libexec/rhts:
PRIVATE_SHELL_SCRIPTS :=  rhts-mk-build-package \
         rhts-mk-get-current-tag rhts-mk-get-next-tag \
         rhts-mk-get-test-package-name rhts-mk-get-version-info \
         rhts-mk-tag-release rhts-mk-snake-template rhts-mk-diff-since-last-tag \
         rhts-mk-get-test-package-url
PRIVATE_PYTHON_SCRIPTS := rhts-mk-test-import rhts-mk-generate-specfile

PUBLIC_FILES := $(PUBLIC_SHELL_SCRIPTS) $(PUBLIC_PYTHON_SCRIPTS)
PRIVATE_FILES := $(PRIVATE_SHELL_SCRIPTS) $(PRIVATE_PYTHON_SCRIPTS)

SHELL_SCRIPTS := $(PUBLIC_SHELL_SCRIPTS) $(PRIVATE_SHELL_SCRIPTS)
PYTHON_SCRIPTS := $(PUBLIC_PYTHON_SCRIPTS) $(PRIVATE_PYTHON_SCRIPTS)

install:
	mkdir -p $(DESTDIR)/usr/bin
	for file in $(PUBLIC_FILES); do install -m 755 $$file $(DESTDIR)/usr/bin; done
	mkdir -p $(DESTDIR)/usr/libexec/rhts
	for file in $(PRIVATE_FILES); do install -m 755 $$file $(DESTDIR)/usr/libexec/rhts; done
