# rear-automated-testing
Relax-and-Recover (ReaR) Automated Testing is using Vagrant and standard GNU/Linux boxes to deploy one server and one client virtual machine (VM), and besides a recover VM is also created, but not provisioned. The main goal of this project is to foresee in a simple way to test the latest snapshot release of ReaR without too many manual interactions by doing a full backup with an automated restore into the *recover* VM.

In short we start the *client* and *server* VM via vagrant, and do a provisioning if required so that the *server* VM is capable of being a NFS server, PXE server and TFTP server. Then, we install the latest **ReaR** snapshot in the *client* VM and run a full backup using the *NETFS* backup method (with the help of `tar` or *bareos*). The tar archive is stored on the *server* VM and in the same time the PXE environment is configured on the *server* VM as well (when using KVM/libvirt), or a PXE environment is configured on the host system when using virtualbox..
When the ReaR backup is completed we halt the *client* VM and start the *recover* VM and do a full restore of the *client* content. Once the restore is completed the *recover* VM reboot automatically.

## Clone this Git repository

`$ git clone https://github.com/gdha/rear-automated-testing.git`

## Execute the automated ReaR Recovery test

Select the GNU/Linux OS to test by going into the proper directory. However, initially we only have **centos7**, but more will follow over time (and do not forget it goes much faster with *sponsoring* - Ubuntu 14.04 and Ubuntu 16.04 were added with sponsoring).

````
$ cd rear-automated-testing
$ sudo ./rear-automated-test.sh -h
Usage: rear-automated-test.sh [-d distro] [-b <boot method>] [-s <stable rear version>] [-p provider] [-c rear-config-file.conf] [-t test] -vh
        -d: The distribution to use for this automated test (default: centos7)
        -b: The boot method to use by our automated test (default: PXE)
        -s: The <stable rear version> is the specific version we want to test, e.g. 2.3 (default: <empty> )
        -p: The vagrant <provider> to use (default: virtualbox)
        -c: The ReaR config file we want to use with this test (default: PXE-booting-example-with-URL-style.conf)
        -l: The ReaR test logs top directory (default: /export/rear-tests/logs)
        -t: The ReaR validation test directory (see tests directory; no default)
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
<test-dir>: under the tests/ directory there are sub-directories with the beakerlib tests (donated by RedHat)
       When -t option is used then we will not execute an automated recover test (at least not yet)
````

### Using KVM/libvirt

To use this tool on a KVM/libvirt Linux system and as CentOS7 and PXE are the default we only require one parameter and that is `-p libvirt` as virtualbox was choosen as the default provider. Be aware, this only works under Linux.

### Using VirtualBox

To use this tool on a VirtualBox with Linux or OS/X system and to test of GNU/Linux operating system CentOS 7, Ubuntu 14.04 or Ubuntu 16.04 and with boot methods PXE or ISO. The tool will try to set-up an FTPboot area on the host system itself. However, it is imported that the hosts system is a NFS server as the client VM will try to mount the TFTboot area. Why do we need the host system? That is because VirtualBox uses a NAT network to PXE boot from and that is always pointing the host system (a pity we cannot use the server VM).

To setup a NFS server (when using VirtualBox) on the host system create a /etc/exports file that looks like:

- Linux:
````
/export 192.168.0.0/16(rw,no_root_squash) 10.0.2.0/24(rw,insecure,no_root_squash) 127.0.0.1(rw,insecure,no_root_squash)
/root/.config/VirtualBox/TFTP 192.168.0.0/16(rw,no_root_squash) 10.0.2.0/24(rw,insecure,no_root_squash) 127.0.0.1(rw,insecure,no_root_squash)
````

- OS/X:
````
/   -alldirs  -rw  -maproot=0:0 -sec=sys:krb5  -network 192.168.33.0 -mask 255.255.255.0
````

Use the `showmount -e` command to check if the export was successfull. 

### ReaR configuration files

There are several ReaR configuration files available under the templates directory.
