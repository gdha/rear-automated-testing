---
title: rear-automated-test.sh
---

# Script rear-automated-test.sh

The script `rear-automated-test.sh` is the hart of the "Relax-and-Recover Automated Testing" project. The functions used by this script are located under the `lib/` sub-directory.

It is important to know you need **root* priveleges to run this script.
 
## Usage of the script (help option)

Currently there is no man page for this script, but the *help* option should be sufficient to get you going.

```
 sudo ./rear-automated-test.sh -h
Usage: rear-automated-test.sh [-d distro] [-b <boot method>] [-s <stable rear version>] [-p provider] [-c rear-config-file.conf] -vh
        -d: The distribution to use for this automated test (default: centos7)
        -b: The boot method to use by our automated test (default: PXE)
        -s: The <stable rear version> is the specific version we want to test, e.g. 2.3 (default: <empty> )
        -p: The vagrant <provider> to use (default: virtualbox)
        -c: The ReaR config file we want to use with this test (default: PXE-booting-example-with-URL-style.conf)
        -l: The ReaR test logs top directory (default: /export/rear-tests/logs)
        -h: This help message.
        -v: Revision number of this script.

Comments:
--------
<distro>: select the distribution you want to use for these testings
<boot method>: select the rescue image boot method (default PXE) - supported are PXE and ISO
<stable rear version>: select the specific version to test, e.g. 2.3. Empty means use the latest unstable version
<provider>: as we use vagrant we need to select the provider to use (virtualbox, libvirt)
<rear-config-file.conf>: is the ReaR config file we would like to use to drive the test scenario with (optional with PXE)
<logs directory>: is the direcory where the logs are kept of each run including the rear recovery log of the recover VM
````

