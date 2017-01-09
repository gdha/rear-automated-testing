#!/bin/bash
#
# rear-automated-test.sh script

# Define generic variables
PRGNAME=${0##*/}
VERSION=1.0

distro="centos7"	# default distro when no argument is given
boot_method="PXE"	# default boot method to use to recover rear on 'recover' VM

client="192.168.33.10"
server="192.168.33.15"
boot_server="$server"	# when using Oracle VirtualBox with PXE booting then the boot server needs to be host
			# In case of KVM we can use $server VM to boot from
# Default tftpboot root directory (for libvirt we keep the default; for virtualbox we need vb TFTP path (defined later)
# The ReaR config templates need to be edited and replaced with the proper path (automatically done)
pxe_tftpboot_path="/export/nfs/tftpboot"

# Vagrant variables
# VAGRANT_DEFAULT_PROVIDER is an official variable vagrant supports, so we re-use this for our purposes as well
VAGRANT_DEFAULT_PROVIDER=virtualbox	# default select virtualbox

#############
# functions #
#############

function IsNotPingable {
    case $(uname -s) in
        CYGWIN*) ping -n 1 $1 2>&1 | grep -qE '(timed out|host unreachable)'
                 rc=$?
                 ;;
        Linux|Darwin) ping -c 1 $1 2>&1 | grep -q "100% packet loss"
                 rc=$?
                 ;;
            *  ) ping -c 1 $1 2>&1 | grep -q "100% packet loss"
                 rc=$?
                 ;;
    esac
    # rc=0 when host is unreachable
    return $rc
}

function helpMsg {
    cat <<eof
Usage: $PRGNAME [-d <distro>] [-b <boot method>] [-s <server IP>] [-p provider] [-c <rear-config-file.conf> -vh
        -d: The distribution to use for this automated test (default: $distro)
        -b: The boot method to use by our automated test (default: $boot_method)
        -s: The <boot server> IP address (default: $boot_server)
	-p: The vagrant <provider> to use (default: $VAGRANT_DEFAULT_PROVIDER)
	-c: The ReaR config file we want to use with this test (default: PXE-booting-example-with-URL-style.conf)
        -h: This help message.
        -v: Revision number of this script.

Comments:
--------
distro: select the distribution you want to use for these testings
boot method: select the rescue image boot method (default PXE) - supported are PXE and ISO
boot server: is the server where the PXE or ISO images resides on (could be the hypervisor or host system)
provider: as we use vagrant we need to select the provider to use (virtualbox, libvirt)
rear-config-file.conf: is the ReaR config file we would like to use to drive the test scenario with (optional with PXE)
eof
}

function Error {
    :
}

########################################################################
## M A I N
########################################################################

echo "
+--------------------------------------------------+
|    Relax-and-Recover Automated Testing script    |
|             version $VERSION                          |
+--------------------------------------------------+

Author: Gratien D'haese
Copyright: GPL v3

"


if [[ $(id -u) -ne 0 ]] ; then
    case $(uname -s) in
        Linux)
            echo "Please run $PRGNAME as root"
            exit 1
            ;;
        CYGWIN*) : # no root required
            ;;
            *) : # no root required??
            ;;
    esac
fi

while getopts ":d:b:s:p:c:vh" opt; do
    case "$opt" in
        d) distro="$OPTARG" ;;
        b) boot_method="$OPTARG" ;;
	s) boot_server="$OPTARG" ;;
	p) provider="$OPTARG" ;;
	c) config="$OPTARG" ;;
        h) helpMsg; exit 0 ;;
        v) echo "$PRGNAME version $VERSION"; exit 0 ;;
       \?) echo "$PRGNAME: unknown option used: [$OPTARG]."
           helpMsg; exit 0 ;;
    esac
done
shift $(( OPTIND - 1 ))

# check if vagrant is present
if ! type -p vagrant &>/dev/null ; then
    echo "ERROR: Please install Vagrant 1.8.7 or higher"
    exit 1
fi

# check if <distro> directory exists?
if [[ ! -d "$distro" ]] ; then
    echo "ERROR: Could not find directory '$distro'"
    echo "       Distribution $distro is not (yet) by $PRGNAME"
    echo "       You can always sponsor this - see README.md"
    exit 1 
fi

# define a proper supported vagrant provider
case "$provider" in
	"") # use default VAGRANT_DEFAULT_PROVIDER as defined in the beginning
	    : ;;
	"libvirt") VAGRANT_DEFAULT_PROVIDER="libvirt" ;;
	"virtualbox") VAGRANT_DEFAULT_PROVIDER="virtualbox" ;;
	*) echo "ERROR: vagrant provider $provider is not (yet) supported by $PRGNAME"
	   echo "       You can always sponsor this - see README.md"
	   exit 1 ;;
esac
export VAGRANT_DEFAULT_PROVIDER

# ReaR config file selection check
if [[ ! -z "$config" ]] && [[ -f "$config" ]] ; then
    REAR_CONFIG="$config"
else
    # most likelya no argument was supplied and therefore, $config is empty = use default PXE template
    REAR_CONFIG=../templates/PXE-booting-with-URL-style.conf
fi

# hard-code the correct security settings on vagrant SSH keys
if [[ -f insecure_keys/vagrant.private ]] ; then
    chmod 600 insecure_keys/vagrant.private
    chmod 644 insecure_keys/vagrant.public
else
    echo "ERROR: file insecure_keys/vagrant.private not found"
    exit 1
fi

#
# When virtualbox is in play then on the hypervisor/host tftpboot and dhcpd must be configured to boot PXE
# We should check this (Todo) Directory /export/nfs/tftpboot should exist and /export must be exported as well
#

Current_dir=$(pwd)
################################
# Entering directory $distro
cd "$distro"
echo "Current distro directory is $distro"
################################

# Before starting vagrant we need to copy the Vagrantfile for the proper provider (VAGRANT_DEFAULT_PROVIDER)
echo "Copy the Vagrantfile.$VAGRANT_DEFAULT_PROVIDER to Vagrantfile"
cp Vagrantfile.$VAGRANT_DEFAULT_PROVIDER Vagrantfile

# start up and client server vagrant VMs (the recover VM stays down)
echo "Bringing up the vagrant VMs client and server"
vagrant up
echo
echo "Sleep for 5 seconds"
sleep 5

echo
vagrant status

echo

# if we are dealing with virtualbox if might be that $client/$server are not pingable due to an
# bug in vagrant itself
# Work-around is to check if "eth1" is active - if not then restart the network
echo "Check if 'eth1' is active on client [known issue https://github.com/mitchellh/vagrant/issues/8166]"
vagrant ssh client -c "sudo su -c \"ip addr show dev eth1 | grep -q DOWN && systemctl restart network.service\""

echo "Check if 'eth1' is active on server"
vagrant ssh server -c "sudo su -c \"ip addr show dev eth1 | grep -q DOWN && systemctl restart network.service\""

echo "Doing ping tests to VMs client and server"
if IsNotPingable $client ; then
    echo "VM $client is not pingable - please investigate why"
    exit 1
else
    echo "VM $client is up and running - ping test OK"
fi


if IsNotPingable $server ; then
    echo "VM $server is not pingable - please investigate why"
    exit 1
else
    echo "VM $server is up and running - ping test OK"
fi

# first update rear inside VM client
echo
echo "Update rear on the VM client"
ssh -i ../insecure_keys/vagrant.private root@$client "yum -y update rear"
echo

# PXE/ISO boot server - for ISO boot_server should always be defined
# for PXE with virtualbox we need boot_server (the host); with libvirt we can PXE boot from the server VM
# However, with virtualbox the boot_server should be 10.0.2.2 which is not pingable from here :-//
# My advise, do not define $boot_server as argument with virtualbox
# Perhaps it is not required anymore?? Need to think about it....
#if [[ "$server" != "$boot_server" ]] ; then
#    # the hypervisor or host system must be reachable of course
#    if IsNotPingable $boot_server ; then
#        echo "System $boot_server is not pingable - please investigate why"
#        exit 1
#    else
#        echo "System $boot_server is up and running - ping test OK"
#    fi
#fi

# According the boot_method we can do different stuff now:
case $boot_method in
#~~~~~~~~~~~~~~~~~~
PXE)
####
    case $VAGRANT_DEFAULT_PROVIDER in
        virtualbox) boot_server="10.0.2.2"
                    pxe_tftpboot_path="/root/.config/VirtualBox/TFTP"
                    [[ ! -d "$pxe_tftpboot_path" ]] && mkdir -p -m 755 "$pxe_tftpboot_path"
                    ;;
        #libvirt)   we use the $server to PXE boot from
    esac

    # Copy the ReaR config template to the client VM, but first we need to replace @server@ and @boot_server@ with the
    # real values defined with arguments given or use the default ones
    sed -e "s/@server@/$server/g" -e "s/@boot_server@/$boot_server/g" \
        -e "s/@pxe_tftpboot_path@/$pxe_tftpboot_path/g" < $REAR_CONFIG > /tmp/rear_config.$$
    echo "Configure rear on client to use OUTPUT=PXE method"
    scp -i ../insecure_keys/vagrant.private /tmp/rear_config.$$ root@$client:/etc/rear/local.conf
    echo

    echo "Copy PXE post script to disable PXE booting after sucessful 'rear recover'"
    ssh -i ../insecure_keys/vagrant.private root@$client "mkdir -p -m 755 /usr/share/rear/wrapup/PXE/default"
    scp -i ../insecure_keys/vagrant.private ../rear-scripts/200_inject_default_boothd0_boot_method.sh root@$client:/usr/share/rear/wrapup/PXE/default/200_inject_default_boothd0_boot_method.sh

    ;;
#~~~~~~~~~~~~~~~~~~~~
ISO)
####
   echo "WARNING: Sorry 'not' (yet completely) implemented by $PRGNAME"
   case $VAGRANT_DEFAULT_PROVIDER in
       virtualbox) boot_server="10.0.2.2" ;;
       libvirt)    boot_server="192.168.33.1" ;;
   esac

   sed -e "s/@server@/$server/g" -e "s/@boot_server@/$boot_server/g" < $REAR_CONFIG > /tmp/rear_config.$$
   echo "Configure rear on client to use OUTPUT=ISO method"
   scp -i ../insecure_keys/vagrant.private /tmp/rear_config.$$ root@$client:/etc/rear/local.conf
   echo

   ;;
#~~~~~~~~~~~~~~~~~~~~
*)
    echo "ERROR: Boot method $boot_method 'not' yet foreseen by $PRGNAME"
    exit 1
    ;;
esac

# remove the temporary ReaR config file from this host
rm -f /tmp/rear_config.$$

echo "Run 'rear -v mkbackup'"
ssh -i ../insecure_keys/vagrant.private root@$client "rear -v mkbackup"
rc=$?

echo
if [[ $rc -ne 0 ]] ; then
    echo "Please check the rear logging /var/log/rear/rear-client.log"
    echo "The last 20 lines are:"
    ssh -i ../insecure_keys/vagrant.private root@$client "tail -20 /var/log/rear/rear-client.log"
    echo
    echo "Check yourself via 'vagrant ssh client'"
    exit 1
else
    echo "The rear mkbackup was successful"
    echo
fi

# According the boot_method we can do different stuff now:
case $boot_method in
    PXE)
    ####

    # For PXE access we have to make sure that on the server the client area is readable for others
    # In my ~/.ssh/config file I defined the line "UserKnownHostsFile /dev/null" to avoid issues
    # with duplicate host keys (after re-installing from scratch the VMs)

    echo "Make client area readable for others on server"
    case $VAGRANT_DEFAULT_PROVIDER in
       virtualbox) chmod 755 /export/nfs/tftpboot/client
       libvirt)    ssh -i ../insecure_keys/vagrant.private root@$boot_server "chmod 755 /export/nfs/tftpboot/client"
                   ;;
    esac
    echo
    ;;

    ISO)
    ####
    # Todo: clean up the PXE area to avoid PXE booting?
    :
    ;;

esac

echo "Halting the client VM (before doing the recovery)"
echo "Recover VM will use the client IP address after it has been fully restored"
echo
vagrant halt client
echo

echo "Starting the recover VM"
vagrant up recover

type -p vncviewer >/dev/null
rc=$?
if [[ $rc -ne 0 ]] ; then
    echo "To see what happens install vncviewer, or use 'vagrant ssh recover'"
    echo
else
    echo "Script will pauze until you disconnect from the 'vncviewer' application"
    echo
    vncviewer 127.0.0.1:5993 
fi

# Go back to original starting directory
cd $Current_dir

exit 0
