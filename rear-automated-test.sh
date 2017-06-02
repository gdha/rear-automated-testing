#!/bin/bash
#
# rear-automated-test.sh script


# Define generic variables
PRGNAME=${0##*/}
PRGDIR=$(pwd)
VERSION=1.0

distro="centos7"	# default distro when no argument is given
boot_method="PXE"	# default boot method to use to recover rear on 'recover' VM

client="192.168.33.10"
server="192.168.33.15"
boot_server="$server"	# when using Oracle VirtualBox with PXE booting then the boot server needs to be host
			# In case of KVM we can use $server VM to boot from
# Default tftpboot root directory (for libvirt we keep the default; for virtualbox we need vb TFTP path (defined later)
# The ReaR config templates need to be edited and replaced with the proper path (automatically done)
# Variable pxe_tftpboot_path will be set by function define_pxe_tftpboot_path
# pxe_tftpboot_path="/export/nfs/tftpboot"

# Vagrant variables
# VAGRANT_DEFAULT_PROVIDER is an official variable vagrant supports, so we re-use this for our purposes as well
VAGRANT_DEFAULT_PROVIDER=virtualbox	# default select virtualbox

DO_TEST=		# execute a validation test (default no)

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

function findUser() {
    thisPID=$$
    origUser=$(whoami)
    thisUser=$origUser

    while [ "$thisUser" = "$origUser" ]
    do
        ARR=($(ps h -p$thisPID -ouser,ppid;))
        thisUser="${ARR[0]}"
        myPPid="${ARR[1]}"
        thisPID=$myPPid
    done

    getent passwd "$thisUser" | cut -d: -f1
}


function helpMsg {
    cat <<eof
Usage: $PRGNAME [-d distro] [-b <boot method>] [-s <server IP>] [-p provider] [-c rear-config-file.conf] [-t test] -vh
        -d: The distribution to use for this automated test (default: $distro)
        -b: The boot method to use by our automated test (default: $boot_method)
        -s: The <boot server> IP address (default: $boot_server)
	-p: The vagrant <provider> to use (default: $VAGRANT_DEFAULT_PROVIDER)
	-c: The ReaR config file we want to use with this test (default: PXE-booting-example-with-URL-style.conf)
	-t: The ReaR validation test directory (see tests directory; no default)
        -h: This help message.
        -v: Revision number of this script.

Comments:
--------
<distro>: select the distribution you want to use for these testings
<boot method>: select the rescue image boot method (default PXE) - supported are PXE and ISO
<boot server>: is the server where the PXE or ISO images resides on (could be the hypervisor or host system)
<provider>: as we use vagrant we need to select the provider to use (virtualbox, libvirt)
<rear-config-file.conf>: is the ReaR config file we would like to use to drive the test scenario with (optional with PXE)
<test-dir>: under the tests/ directory there are sub-directories with the beakerlib tests (donated by RedHat).
       When -t option is used then we will not execute an automated recover test (at least not yet)
eof
}

function Error {
    echo "$(bold $(red ERROR: $*))"
    exit 1
}

# usage example of colored output: echo "some $(bold $(red hello world)) test"
function bold {
    ansi 1 "$@";
}

function italic {
     ansi 3 "$@";
}

function underline {
     ansi 4 "$@";
}

function strikethrough {
     ansi 9 "$@";
}

function red {
     ansi 31 "$@";
}

function green {
     ansi 32 "$@";
}

function ansi {
     echo -e "\e[${1}m${*:2}\e[0m";
}

function define_pxe_tftpboot_path {
    # pxe_tftpboot_path path is need by boot methods PXE and ISO
    # PXE to fill up the client PXE boot configs
    # ISO to remove to client PXE configs (otherwise we boot from PXE or boothd0)
    case $VAGRANT_DEFAULT_PROVIDER in
        virtualbox) 
                    # with VirtualBox the TFTP boot path is under:
                    pxe_tftpboot_path="/root/.config/VirtualBox/TFTP"   
                    ;;
        libvirt) 
                    # has already been defined in the default settings
                    pxe_tftpboot_path="/export/nfs/tftpboot"
                    ;;
    esac
    echo $pxe_tftpboot_path
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
            Error "Please run $PRGNAME as root"
            ;;
        CYGWIN*) : # no root required
            ;;
            *) : # no root required??
            ;;
    esac
fi

while getopts ":d:b:s:p:c:t:vh" opt; do
    case "$opt" in
        d) distro="$OPTARG" ;;
        b) boot_method="$OPTARG" ;;
	s) boot_server="$OPTARG" ;;
	p) provider="$OPTARG" ;;
	c) config="$OPTARG"
           [[ ! -f "$config" ]] && Error "ReaR Configuration file $config not found."
           ;;
	t) test_dir="$OPTARG"
	   DO_TEST="y"
	   [[ ! -d "tests/$test_dir" ]] && Error "Test directory tests/$test_dir not found"
	   ;;
        h) helpMsg; exit 0 ;;
        v) echo "$PRGNAME version $VERSION"; exit 0 ;;
       \?) echo "$PRGNAME: unknown option used: [$OPTARG]."
           helpMsg; exit 0 ;;
    esac
done
shift $(( OPTIND - 1 ))

# check if vagrant is present
if ! type -p vagrant &>/dev/null ; then
    Error "Please install Vagrant 1.8.7 or higher"
fi

# check if <distro> directory exists?
if [[ ! -d "$distro" ]] ; then
    echo "$(bold $(red ERROR: Could not find directory '$distro'))"
    echo "       Distribution $distro is not (yet) supported by $PRGNAME"
    echo "       You can always sponsor this - see README.md"
    exit 1 
fi

# define a proper supported vagrant provider
case "$provider" in
	"") # use default VAGRANT_DEFAULT_PROVIDER as defined in the beginning
	    : ;;
	"libvirt") VAGRANT_DEFAULT_PROVIDER="libvirt" ;;
	"virtualbox") VAGRANT_DEFAULT_PROVIDER="virtualbox" ;;
	*) echo "(bold $(red ERROR: vagrant provider $provider is not (yet) supported by $PRGNAME))"
	   echo "       You can always sponsor this - see README.md"
	   exit 1 ;;
esac
export VAGRANT_DEFAULT_PROVIDER

# We have chosen the proper provider - did we? Check the basics - are the main paths there or not?
case $VAGRANT_DEFAULT_PROVIDER in
    libvirt)
        [[ ! -d /var/lib/libvirt ]] && Error "Libvirt seems not to be installed - use another provider perhaps"
        ;;
    virtualbox) 
        [[ ! -d /usr/lib/virtualbox ]] && Error "VirtualBox seems not to be installed - use another provider perhaps"
        ;;
esac

# Check and/or add the client/server IP addresses to the local /etc/hosts file
grep -q "^$client" /etc/hosts
if [[ $? -eq 1 ]] ;then
   echo "Add IP addresses of client and server to /etc/hosts file (on the vagrant host)"
   echo "192.168.33.10   vagrant-client" >> /etc/hosts
   echo "192.168.33.15   vagrant-server" >> /etc/hosts
   echo "192.168.33.1    vagrant-host" >> /etc/hosts
fi

# Verify the real user's .ssh/config file
user=$(findUser)
my_home=$(getent passwd | grep ^${user} | cut -d: -f6)
[[ ! -f "$my_home/.ssh/config" ]] && touch "$my_home/.ssh/config"
grep -q "vagrant-client" "$my_home/.ssh/config" 2>/dev/null
if [[ $? -ge 1 ]] ;then
    echo "HOST vagrant-client vagrant-server" >> "$my_home/.ssh/config"
    echo "     CheckHostIP no" >> "$my_home/.ssh/config"
    echo "     StrictHostKeyChecking no" >> "$my_home/.ssh/config"
    echo "     UserKnownHostsFile /dev/null" >> "$my_home/.ssh/config"
    echo "     VerifyHostKeyDNS no" >> "$my_home/.ssh/config"
fi

# ReaR config file selection check
if [[ ! -z "$config" ]] && [[ -f "$config" ]] ; then
    REAR_CONFIG="$PRGDIR/templates/$( basename $config )"  # use full path
else
    # most likely no argument was supplied and therefore, $config is empty = use default PXE template
    REAR_CONFIG=../templates/PXE-booting-with-URL-style.conf
fi

# hard-code the correct security settings on vagrant SSH keys
if [[ -f insecure_keys/vagrant.private ]] ; then
    chmod 600 insecure_keys/vagrant.private
    chmod 644 insecure_keys/vagrant.public
else
    Error "file insecure_keys/vagrant.private not found"
fi

#
# When virtualbox is in play then on the hypervisor/host tftpboot and dhcpd must be configured to boot PXE
# We should check this (Todo) Directory /export/nfs/tftpboot should exist and /export must be exported as well
#

Current_dir=$(pwd)
################################
# Entering directory $distro
cd "$distro"
echo "$(bold Current distro directory is $(green $distro))"
################################

# Before starting vagrant we need to copy the Vagrantfile for the proper provider (VAGRANT_DEFAULT_PROVIDER)
echo "Copy the Vagrantfile.$VAGRANT_DEFAULT_PROVIDER to Vagrantfile"
cp Vagrantfile.$VAGRANT_DEFAULT_PROVIDER Vagrantfile

# trap Cntrl-C interrupts during vagrant calls (we will foresee a small time to interrupt
# during a period that is safe - meaning do not scratch a VM box)
trap '' SIGINT

# start up and client server vagrant VMs (the recover VM stays down)
echo "$(italic Bringing up the vagrant VMs client and server)"
vagrant up
echo

trap - SIGINT       # disable the trap
echo "$(italic Sleep for 5 seconds [$(bold Control-C) is now possible])"
sleep 5
echo

echo "------------------------------------------------------------------------------"
vagrant status
echo "------------------------------------------------------------------------------"
echo

# if we are dealing with virtualbox if might be that $client/$server are not pingable due to an
# bug in vagrant itself
# Work-around is to check if "eth1" is active - if not then restart the network
echo "Check if 'eth1' is active on client $(italic [known issue https://github.com/mitchellh/vagrant/issues/8166])"
vagrant ssh client -c "sudo su -c \"ip addr show dev eth1 | grep -q DOWN && systemctl restart network.service\""

echo "Check if 'eth1' is active on server"
vagrant ssh server -c "sudo su -c \"ip addr show dev eth1 | grep -q DOWN && systemctl restart network.service\""

echo "$(bold Doing ping tests to VMs client and server)"
if IsNotPingable $client ; then
    Error "VM $client is not pingable - please investigate why"
else
    echo "$(bold client) is up and running - ping test $(green OK)"
fi


if IsNotPingable $server ; then
    Error "VM $server is not pingable - please investigate why"
else
    echo "$(bold server) is up and running - ping test $(green OK)"
fi

# first update rear inside VM client
echo
echo "$(bold Update rear on the VM client)"
#TODO: uncomment next line when done with debugging ISO auto-recover
ssh -i ../insecure_keys/vagrant.private root@$client "timeout 3m yum --disableplugin=fastestmirror -y update rear" 2>/dev/null
echo

# Option -f test will be executed on 'client' VM only (at least for now)
# Therefore, check if the test is an existing directory for the test we want
if [[ "$DO_TEST" = "y" ]] ; then
    # $test_dir contains the test we want to execute; first copy it to the client vm
    echo "$(bold Copying the Beaker tests onto the VM client)"    
    scp -i ../insecure_keys/vagrant.private -r ../tests root@$client:/var/tmp 2>/dev/null
    # install rear-rhts and beakerlib
    echo "$(italic Install rear-rhts  and beakerlib packages required for the Beaker tests)"
    ssh -i ../insecure_keys/vagrant.private root@$client "timeout 3m yum --disableplugin=fastestmirror -y install rear-rhts beakerlib"
    # on the client vm all tests are available under /var/tmp/tests/
    echo "Executing test $test_dir"
    echo "---------------------------------"
    ssh -i ../insecure_keys/vagrant.private root@$client "cd /var/tmp/tests/$test_dir ; make" 2>/dev/null
    rc=$?
    [[ $rc -gt 0 ]] && Error "make command failed for test $test_dir"
    jFile=/$(ssh -i ../insecure_keys/vagrant.private root@$client 'tail -1 /mnt/testarea/current.log | cut -d/ -f2-' 2>/dev/null)
    # jFile=/var/tmp/beakerlib-lGspW7z/journal.txt for example
    [[ "$jFile" = "/" ]] && Error "Test results file not found on $client (check /mnt/testarea)"
    scp -i ../insecure_keys/vagrant.private root@$client:$jFile ../tests/$test_dir/test-results-of-$(date '+%Y%m%d')
    echo "Saved the results as tests/$test_dir/test-results-of-$(date '+%Y%m%d')"
    exit 0
fi

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
                    # with VirtualBox the TFTP boot path is under:
                    pxe_tftpboot_path=$( define_pxe_tftpboot_path )
                    [[ ! -d "$pxe_tftpboot_path" ]] && mkdir -p -m 755 "$pxe_tftpboot_path"
                    [[ ! -d "$pxe_tftpboot_path/pxelinux.cfg" ]] && mkdir -p -m 755 "$pxe_tftpboot_path/pxelinux.cfg"
                    ;;
        libvirt)   # we use the $server to PXE boot from
                   pxe_tftpboot_path=$( define_pxe_tftpboot_path )
                   ssh -i ../insecure_keys/vagrant.private root@$server "mkdir -p -m 755 $pxe_tftpboot_path/pxelinux.cfg" 2>/dev/null
                   ;;
    esac

    # Copy the ReaR config template to the client VM, but first we need to replace @server@ and @boot_server@ with the
    # real values defined with arguments given or use the default ones
    sed -e "s;@server@;$server;g" -e "s;@boot_server@;$boot_server;g" \
        -e "s;@pxe_tftpboot_path@;$pxe_tftpboot_path;g" < $REAR_CONFIG > /tmp/rear_config.$$
    echo "$(bold Configure rear on client to use $(green OUTPUT=PXE) method)"
    scp -i ../insecure_keys/vagrant.private /tmp/rear_config.$$ root@$client:/etc/rear/local.conf 2>/dev/null
    echo

    echo "Copy PXE post script to disable PXE booting after sucessful 'rear recover'"
    ssh -i ../insecure_keys/vagrant.private root@$client "mkdir -p -m 755 /usr/share/rear/wrapup/PXE/default" 2>/dev/null
    scp -i ../insecure_keys/vagrant.private ../rear-scripts/200_inject_default_boothd0_boot_method.sh root@$client:/usr/share/rear/wrapup/PXE/default/200_inject_default_boothd0_boot_method.sh 2>/dev/null

    ;;
#~~~~~~~~~~~~~~~~~~~~
ISO)
####
   echo "$(red WARNING: Sorry 'not' yet completely tested by $PRGNAME)"
   case $VAGRANT_DEFAULT_PROVIDER in
       virtualbox) boot_server="10.0.2.2"
                   pxe_tftpboot_path=$( define_pxe_tftpboot_path )
                   [[ ! -d "$pxe_tftpboot_path" ]] && mkdir -p -m 755 "$pxe_tftpboot_path"
                   [[ ! -d "$pxe_tftpboot_path/pxelinux.cfg" ]] && mkdir -p -m 755 "$pxe_tftpboot_path/pxelinux.cfg"
                   # ISO images are stored under /export/isos/client - we will make a soft link to it
                   # in our pxelinux config file rear-client we will use this for the ISO menu
                   [[ ! -h "$pxe_tftpboot_path/isos" ]] && ln -s /export/isos "$pxe_tftpboot_path/isos"
                   # we need memdisk to boot an ISO image
                   [[ -f /usr/share/syslinux/memdisk ]] && cp -p /usr/share/syslinux/memdisk "$pxe_tftpboot_path"
                   ;;
       libvirt)    pxe_tftpboot_path=$( define_pxe_tftpboot_path )
                   boot_server="192.168.33.15"
                   ssh -i ../insecure_keys/vagrant.private root@$server "mkdir -p -m 755 $pxe_tftpboot_path/pxelinux.cfg" 2>/dev/null
                   ssh -i ../insecure_keys/vagrant.private root@$server "[[ ! -h "$pxe_tftpboot_path/isos" ]] && ln -s /export/isos $pxe_tftpboot_path/isos"
                   ssh -i ../insecure_keys/vagrant.private root@$server "[[ -f /usr/share/syslinux/memdisk ]] && cp -p /usr/share/syslinux/memdisk $pxe_tftpboot_path"
                   
                   ;;
   esac

   # We expect that the REAR_CONFIG was an argument with this script
   sed -e "s/@server@/$server/g" -e "s/@boot_server@/$boot_server/g" \
       -e "s;@pxe_tftpboot_path@;$pxe_tftpboot_path;g" < $REAR_CONFIG > /tmp/rear_config.$$
   echo "$(bold Configure rear on client to use $(green OUTPUT=ISO) method)"
   scp -i ../insecure_keys/vagrant.private /tmp/rear_config.$$ root@$client:/etc/rear/local.conf 2>/dev/null
   echo
   # We need to check the OUTPUT_URL/BACKUP_URL paths on the server side; if paths do not exist create them
   if grep -q ^OUTPUT_URL /tmp/rear_config.$$ ; then
       url=$( grep ^OUTPUT_URL /tmp/rear_config.$$ | cut -d= -f 2 )
       url_without_scheme=${url#*//}
       my_path="/${url_without_scheme#*/}"
       my_server="${url_without_scheme%%/*}"
       if [[ "$my_server" = "$boot_server" ]] ; then
           mkdir -m 755 -p $my_path
       else
           ssh -i ../insecure_keys/vagrant.private root@$my_server "mkdir -p -m 755 $my_path"
       fi
   fi
   if grep -q ^BACKUP_URL /tmp/rear_config.$$ ; then
       url=$( grep ^BACKUP_URL /tmp/rear_config.$$ | cut -d= -f 2 )
       url_without_scheme=${url#*//}
       my_path="/${url_without_scheme#*/}"
       my_server="${url_without_scheme%%/*}"
       if [[ "$my_server" = "$boot_server" ]] ; then
           mkdir -m 755 -p $my_path
       else
           ssh -i ../insecure_keys/vagrant.private root@$my_server "mkdir -p -m 755 $my_path"
       fi
   fi
   ssh -i ../insecure_keys/vagrant.private root@$client "mkdir -p -m 755 /usr/share/rear/wrapup/ISO/default" 2>/dev/null
   scp -i ../insecure_keys/vagrant.private ../rear-scripts/200_inject_default_boothd0_boot_method.sh root@$client:/usr/share/rear/wrapup/ISO/default/200_inject_default_boothd0_boot_method.sh 2>/dev/null

   ;;
#~~~~~~~~~~~~~~~~~~~~
*)
    Error "Boot method $boot_method 'not' yet foreseen by $PRGNAME"
    ;;
esac

# remove the temporary ReaR config file from this host
rm -f /tmp/rear_config.$$

echo
echo "$(bold ReaR version that will be tested is:)"
ssh -i ../insecure_keys/vagrant.private root@$client "rear -V" 2>/dev/null
echo

echo "$(bold Content of /etc/rear/local.conf is:)"
ssh -i ../insecure_keys/vagrant.private root@$client "grep -v \# /etc/rear/local.conf" 2>/dev/null
echo

echo "$(bold Run 'rear -v mkbackup')"
ssh -i ../insecure_keys/vagrant.private root@$client "rear -v mkbackup" 2>/dev/null
rc=$?

echo
if [[ $rc -ne 0 ]] ; then
    echo "$(red Please check the rear logging /var/log/rear/rear-client.log)"
    echo "The last 20 lines are:"
    ssh -i ../insecure_keys/vagrant.private root@$client "tail -20 /var/log/rear/rear-client.log" 2>/dev/null
    echo
    Error "Check yourself via 'vagrant ssh client'"
else
    echo "$(bold $(green The rear mkbackup was successful))"
    echo
fi

# According the boot_method we can do different stuff now:
case $boot_method in
    PXE)
    ####

    # For PXE access we have to make sure that on the server the client area is readable for others
    # In my ~/.ssh/config file I defined the line "UserKnownHostsFile /dev/null" to avoid issues
    # with duplicate host keys (after re-installing from scratch the VMs)

    echo "$(bold Make client area readable for others on PXE boot server $(green $boot_server))"
    case $VAGRANT_DEFAULT_PROVIDER in
       virtualbox) chmod 755 "$pxe_tftpboot_path"/client
                   ;;
       libvirt)    ssh -i ../insecure_keys/vagrant.private root@$boot_server "chmod 755 /export/nfs/tftpboot/client" 2>/dev/null
                   ;;
    esac
    echo
    ;;

    ISO)
    ####
    # Todo: clean up the PXE area to avoid PXE booting?
    pxe_tftpboot_path=$( define_pxe_tftpboot_path )
    case $VAGRANT_DEFAULT_PROVIDER in
       virtualbox) [[ ! -d "$pxe_tftpboot_path"/client ]] && mkdir -p -m 755 "$pxe_tftpboot_path"/client
                   chmod 755 "$pxe_tftpboot_path"/client
                   if [[ -d /export/isos/client ]] ; then
                       chmod 755  /export/isos/client
                       chmod 644  /export/isos/client/*.iso
                   else
                       mkdir -p -m 755 /export/isos/client
                   fi
                   # the PXE entry must be created after the rear mkbackup has finished as the pxe cfg file is recreated
                   echo "Copy PXE configuration entry to pxelinux.cfg to enable ISO boot menu entry"
                   # we overwrite any existing pxelinux.cfg file with our template pxelinux-cfg-with-iso-entry
                   cat ../templates/pxelinux-cfg-with-iso-entry > "$pxe_tftpboot_path/pxelinux.cfg/rear-client"
                   ;;
       libvirt)    ssh -i ../insecure_keys/vagrant.private root@$boot_server "chmod -R 755 /export/nfs/tftpboot/client" 2>/dev/null
                   ssh -i ../insecure_keys/vagrant.private root@$boot_server "chmod -R 755 /export/isos/client" 2>/dev/null
                   ssh -i ../insecure_keys/vagrant.private root@$boot_server "chmod 644  /export/isos/client/*.iso" 2>/dev/null
                   scp -i ../insecure_keys/vagrant.private ../templates/pxelinux-cfg-with-iso-entry root@$boot_server:"$pxe_tftpboot_path/pxelinux.cfg/rear-client"
                   ;;
    esac

    ;;

esac

echo "$(bold Halting the client VM $(italic before doing the recovery))"
echo "Recover VM will use the client IP address after it has been fully restored"
echo
vagrant halt client
echo

# For issue #15 with virtualbox and "recover: Warning: Authentication failure. Retrying" we need to copy
# the client private key to the recover directory
case $VAGRANT_DEFAULT_PROVIDER in
    virtualbox) 
        if [[ -f .vagrant/machines/client/virtualbox/private_key ]] ; then
            ##cp .vagrant/machines/client/virtualbox/private_key .vagrant/machines/recover/virtualbox/private_key
            ##echo "Copied private key of client VB to recover VB config area"
            :
        fi
        ;;
esac

echo "$(bold Starting the recover VM)"
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
