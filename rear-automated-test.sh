#!/bin/bash
#
# rear-automated-test.sh script
# Author: Gratien D'haese - IT3 Consultants

# Define generic variables
PRGNAME=${0##*/}
PRGDIR=$(pwd)
VERSION=1.4
DISPLAY=:0

distro="centos7"	# default distro when no argument is given
boot_method="PXE"	# default boot method to use to recover rear on 'recover' VM

client="192.168.33.10"
server="192.168.33.15"
boot_server="$server"	# when using Oracle VirtualBox (VB) with PXE booting then the boot server needs to be host
			# In case of KVM we can use $server VM to boot from
vagrant_host="192.168.33.1" # we use this variable to store the ReaR recover logfile (and is the same for VB and libvirt)

# Default tftpboot root directory (for libvirt we keep the default; for virtualbox we need vb TFTP path (defined later)
# The ReaR config templates need to be edited and replaced with the proper path (automatically done)
# Variable pxe_tftpboot_path will be set by function define_pxe_tftpboot_path
# pxe_tftpboot_path="/export/nfs/tftpboot"

# Vagrant variables
# VAGRANT_DEFAULT_PROVIDER is an official variable vagrant supports, so we re-use this for our purposes as well
VAGRANT_DEFAULT_PROVIDER=virtualbox	# default select virtualbox

DO_TEST=		# execute a validation test (default no)

# LOG_DIR is the top directory where we will keep all our logs from this script incl. the rear recover logs
# LOG_DIR should be a NFS exported file system as the recover VM will mount it to copy its recover log file onto
# The LOG_DIR will finally be renamed to TEST_LOG_DIR=$LOG_DIR/$TIMESTAMP to make it unique across runs
# Finally, LOG_DIR can be given as an argument (with the '-l' option) as well
LOG_DIR=/export/rear-tests/logs
# LOGFILE - we define this after we have read all command line arguments (especially LOG_DIR)

# release_nr is used to capture which "stable" version of ReaR we want to test
# By default, we only test the latest unstable version
release_nr=

MESSAGE_PREFIX=
DEBUG=
CMD_OPTS=( "$@" )

# Keep PID of main process (i.e. the main script that the user had launched as 'rear'):
readonly MASTER_PID=$$

# The command (actually the function) DoExitTasks is executed on exit from the shell:
builtin trap "DoExitTasks" EXIT




#############
# functions #
#############

# Source the lib/*.sh scripts first for our internal function definitions
for script in $PRGDIR/lib/*.sh
do
    source $script
done


########################################################################
## M A I N
########################################################################

if [[ $(id -u) -ne 0 ]] ; then
    case $(uname -s) in
        Linux|Darwin)
            Error "Please run $PRGNAME as root"
            ;;
        CYGWIN*) : # no root required
            ;;
            *) : # no root required??
            ;;
    esac
fi

while getopts ":d:b:s:p:c:l:t:vh" opt; do
    case "$opt" in
        d) distro="$OPTARG" ;;
        b) boot_method="$OPTARG" ;;
	s) release_nr="$OPTARG" ;;
	p) provider="$OPTARG" ;;
	c) config="$OPTARG"
           [[ ! -f "$config" ]] && Error "ReaR Configuration file $config not found."
           ;;
        l) LOG_DIR="$OPTARG" ;;
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

# initialize the LOGFILE and LOG_DIR
if [[ ! -d "$LOG_DIR" ]] ; then
    # this is the top directory of our LOG_DIR - sub-directory with timestamp are automatically created
    mkdir -m 755 -p "$LOG_DIR" || Error "${MESSAGE_PREFIX}Cannot create $LOG_DIR"
fi
# However, for each run we will create a seperate sub-directory beneath LOG_DIR
# with tamestamp entry +%F_%H-%M-%S (e.g. 2017-11-20_17-09-37)
# The TEST_LOG_DIR name which will be used in this script and also by ReaR to mount this to store its recover log
TEST_LOG_DIR="$LOG_DIR/$(date +%F_%H-%M-%S)"   # make it fixed so we can use it in several other places
mkdir -p -m 755 "$TEST_LOG_DIR" || Error "${MESSAGE_PREFIX}Cannot create $TEST_LOG_DIR"


# Define LOGFILE for this script
LOGFILE="$TEST_LOG_DIR/$PRGNAME.log"
cat /dev/null >"$LOGFILE"

# USR1 is used to abort on errors.
# It is not using PrintError but does direct output to the original STDERR.
# Set EXIT_FAIL_MESSAGE to 0 to aviod an additional failed message via the QuietAddExitTask above:
builtin trap "echo '${MESSAGE_PREFIX}Aborting due to an error, check $LOGFILE for details' ; kill $MASTER_PID" USR1

# Redirect both STDOUT and STDERR into the log file.
# To be more on the safe side append to the log file '>>' instead of plain writing to it '>'
# because when a program (bash in this case) is plain writing to the log file it can overwrite
# output of a possibly simultaneously running process that likes to append to the log file
exec 2>>"$LOGFILE"

# Make stdout the same what stderr already is.
# This keeps strict ordering of stdout and stderr outputs
# because now both stdout and stderr use one same file descriptor.
#exec 1>&2

LogPrint "
+--------------------------------------------------+
|    Relax-and-Recover Automated Testing script    |
|             version $VERSION                          |
+--------------------------------------------------+

Author: Gratien D'haese
Copyright: GPL v3

"
LogPrint "Command line options: $PRGNAME ${CMD_OPTS[@]}"
LogPrint "Distribution: $distro"
LogPrint "Boot method: $boot_method"
if [[ -z "$release_nr" ]] ; then
    LogPrint "ReaR version: latest development version"
else
    LogPrint "ReaR version: $release_nr"
fi
if [[ -z "$provider" ]] ; then
    LogPrint "Provider: $VAGRANT_DEFAULT_PROVIDER"
else
    LogPrint "Provider: $provider"
fi
if [[ ! -z "$config" ]] && [[ -f "$config" ]] ; then
    LogPrint "ReaR configuration: $( basename $config )"
else
    LogPrint "ReaR configuration: PXE-booting-with-URL-style.conf"
fi
LogPrint "Log file: $LOGFILE
"

# check if vagrant is present
if ! type -p vagrant &>/dev/null ; then
    Error "Please install Vagrant 1.8.7 or higher"
fi

# check if <distro> directory exists?
if [[ ! -d "$distro" ]] ; then
    Error "Could not find directory '$distro'"
fi

# check which "distro" was last used - if different we should warn the user about it
# as we probably want to destroy the previous vagrant boxes first - we use a symbolic link
# to keep track of the "latest" distro used.
if [[ ! -h "latest" ]] ; then
    # Link does not yet exists - create it
    ln -s "$distro" "latest"
    targetdistro="$distro"
else
    # link "latest" exists - to which distro does it point?
    targetdistro=$( ls -l latest | awk 'NF>1{print $NF}' )
fi

if [[ "$targetdistro" != "$distro" ]] ; then
    LogPrint "It would be better to destroy the Vagrant boxes first of distro $targetdistro"
    LogPrint "before starting doing tests with distro $distro"
    Log "Press 'enter' to continue or Ctrl-C to quit"
    echo "$(bold Press $(green 'enter') to continue or $(red  Ctrl-C) to quit)"
    read junk
    # If we come to this point then Enter was given - rm the latest link and create a new one
    rm -f latest
    ln -s "$distro" "latest"
    Log "Create softlink from distro $distro to latest"
fi

# The following section are steps executed on the hypervisor (this system):

# define a proper supported vagrant provider
case "$provider" in
	"") # use default VAGRANT_DEFAULT_PROVIDER as defined in the beginning
	    : ;;
	"libvirt") VAGRANT_DEFAULT_PROVIDER="libvirt" ;;
	"virtualbox") VAGRANT_DEFAULT_PROVIDER="virtualbox" ;;
	*) Error "vagrant provider $provider is not (yet) supported by $PRGNAME" ;;
esac
export VAGRANT_DEFAULT_PROVIDER

# We have chosen the proper provider - did we? Check the basics - are the main paths there or not?
case $VAGRANT_DEFAULT_PROVIDER in
    libvirt)
        # most likely Linux only
        [[ ! -d /var/lib/libvirt ]] && Error "Libvirt seems not to be installed - use another provider perhaps"
        LogPrint "Using Libvirt as hypervisor"
        ;;
    virtualbox) 
        # can run on Linux, MacOS, Windows
        if [[ -x /usr/bin/VBox ]] || [[ -x /usr/local/bin/VirtualBox ]] ; then
            LogPrint "Using virtualbox as hypervisor"
        else
            Error "VirtualBox seems not to be installed - use another provider perhaps"
        fi
        # do a check if we have a DISPLAY variable defined (recover VM needs it #39)
        export DISPLAY	# especially for MacOS OS/x
        env | grep -q DISPLAY || Error "VirtualBox requires a proper 'DISPLAY' setting"
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

# Verify the real user's and root .ssh/config files
user=$(findUser)
my_home=$(grep ^${user} /etc/passwd | cut -d: -f6)
root_home=$(grep ^root /etc/passwd | cut -d: -f6)
export root_home

for DIR in $root_home $my_home    # added /var/root for MacOS
do
    [[ ! -d "$DIR/.ssh" ]] && mkdir -m 700 -p "$DIR/.ssh"
    # check if there is a ssh key present, if not generate one
    if [[ ! -f "$DIR/.ssh/id_rsa" ]] ; then
        printf "\n\n\n" | ssh-keygen -t rsa -N ""
    fi
    [[ ! -f "$DIR/.ssh/config" ]] && touch "$DIR/.ssh/config"
    grep -q "vagrant-client" "$DIR/.ssh/config" 2>/dev/null
    if [[ $? -ge 1 ]] ;then
        echo "HOST vagrant-client vagrant-server 192.168.33.10 192.168.33.15" >> "$DIR/.ssh/config"
        echo "     CheckHostIP no" >> "$DIR/.ssh/config"
        echo "     StrictHostKeyChecking no" >> "$DIR/.ssh/config"
        echo "     UserKnownHostsFile /dev/null" >> "$DIR/.ssh/config"
        echo "     VerifyHostKeyDNS no" >> "$DIR/.ssh/config"
    fi
done

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
    Error "File insecure_keys/vagrant.private not found"
fi

#
# When virtualbox is in play then on the hypervisor/host tftpboot and dhcpd must be configured to boot PXE
# We should check this (Todo) Directory /export/nfs/tftpboot should exist and /export must be exported as well
#

Current_dir=$(pwd)
################################
# Entering directory $distro
cd "$distro"
Log "Current distro directory is $distro"
echo "$(bold Current distro directory is $(green $distro))"
################################

# Before starting vagrant we need to copy the Vagrantfile for the proper provider (VAGRANT_DEFAULT_PROVIDER)
LogPrint "Copy the Vagrantfile.$VAGRANT_DEFAULT_PROVIDER to Vagrantfile"
# TODO: use sed to replace the @pxe_tftpboot_path@ in Vagrantfile.$VAGRANT_DEFAULT_PROVIDER
cp Vagrantfile.$VAGRANT_DEFAULT_PROVIDER Vagrantfile

# trap Cntrl-C interrupts during vagrant calls (we will foresee a small time to interrupt
# during a period that is safe - meaning do not scratch a VM box)
trap '' SIGINT

######################################################################
# start up and client server vagrant VMs (the recover VM stays down) #
######################################################################
Log "Bringing up the vagrant VMs client and server"
echo "$(italic Bringing up the vagrant VMs client and server)"
vagrant up | tee -a $LOGFILE
LogPrint ""

trap - SIGINT       # disable the trap
Log "Sleep for 5 seconds [Control-C] is now possible"
echo "$(italic Sleep for 5 seconds [$(bold Control-C) is now possible])"
sleep 5
LogPrint ""
Log "Do not use Control-C anymore, or the VMs will be destroyed"
echo "$(italic Do $(red not) use $(bold Control-C) anymore, or the VMs will be destroyed)"

LogPrint "------------------------------------------------------------------------------"
vagrant status | tee -a $LOGFILE
LogPrint "------------------------------------------------------------------------------"
LogPrint ""

# If we are dealing with virtualbox if might be that $client/$server are not pingable due to an
# bug in vagrant itself
# Work-around is to check if "eth1" is active - if not then restart the network
# However, first check how the 2th interface is named (eth1 or enp0s8 or something else):

iface1=$( vagrant ssh server -c "sudo su -c \"ip addr show\" | grep ^3: | cut -d: -f2" )
# The variable iface1 contains a control character which must be removed with a tr command (see below):
lan1=$( echo "$iface1" | tr -cd "[:print:]\n" )

Log "Check if $lan1 is active on client [known issue https://github.com/mitchellh/vagrant/issues/8166]"
echo "Check if $lan1 is active on client $(italic [known issue https://github.com/mitchellh/vagrant/issues/8166])"
vagrant ssh client -c "sudo su -c \"ip addr show dev $lan1 | grep -q DOWN && systemctl restart network.service\""

LogPrint "Check if $lan1 is active on server"
vagrant ssh server -c "sudo su -c \"ip addr show dev $lan1 | grep -q DOWN && systemctl restart network.service\""

Log "Doing ping tests to VMs client and server"
echo "$(bold Doing ping tests to VMs client and server)"
if IsNotPingable $client ; then
    Error "VM $client is not pingable - please investigate why"
else
    Log "client is up and running - ping test OK"
    echo "$(bold client) is up and running - ping test $(green OK)"
fi


if IsNotPingable $server ; then
    Error "VM $server is not pingable - please investigate why"
else
    Log "server is up and running - ping test OK"
    echo "$(bold server) is up and running - ping test $(green OK)"
fi

# first update rear inside VM client
LogPrint ""
if [[ -z "$release_nr" ]] ; then
    # We will test the latest unstable ReaR version
    Log "Update rear on the VM client"
    echo "$(bold Update rear on the VM client)"
    case "$distro" in
        (ubuntu*)
            # Ubuntu does not always update ReaR properly; therefore, we better first remove the package and re-install it
            ssh -i ../insecure_keys/vagrant.private root@$client "timeout 3m apt -y remove rear" | tee -a $LOGFILE
            ssh -i ../insecure_keys/vagrant.private root@$client "timeout 3m apt-get update" | tee -a $LOGFILE
            ssh -i ../insecure_keys/vagrant.private root@$client "timeout 3m apt-get -y --force-yes install rear" | tee -a $LOGFILE
            ;;
        (centos*)
            ssh -i ../insecure_keys/vagrant.private root@$client "timeout 3m yum --disableplugin=fastestmirror -y update rear" | tee -a $LOGFILE
            ;;
       (fedora*)
            ssh -i ../insecure_keys/vagrant.private root@$client "timeout 3m dnf --disableplugin=fastestmirror -y update rear" | tee -a $LOGFILE
            ;;
        (sles*)
            ssh -i ../insecure_keys/vagrant.private root@$client "timeout 3m rpm -e rear" | tee -a $LOGFILE
            ssh -i ../insecure_keys/vagrant.private root@$client "timeout 3m zypper --non-interactive ref" | tee -a $LOGFILE
            ssh -i ../insecure_keys/vagrant.private root@$client "timeout 3m zypper --non-interactive install rear" | tee -a $LOGFILE
            ;;
    esac

else
    # We will try to install the request "stable" ReaR version
    # PS: we will not test if the var release_nr makes sense - if not, the install will fail (force exit)?
    Log "Install the stable ReaR version $release_nr"
    echo "$(bold Install stable ReaR version $release_nr on the VM client)"
    case "$distro" in
        (ubuntu*)
            ssh -i ../insecure_keys/vagrant.private root@$client "timeout 3m apt -y remove rear" | tee -a $LOGFILE
            ssh -i ../insecure_keys/vagrant.private root@$client "timeout 3m apt-get update" | tee -a $LOGFILE
            ssh -i ../insecure_keys/vagrant.private root@$client "timeout 3m apt-get -y --force-yes install rear" | tee -a $LOGFILE
            ;;
        (centos*)
            ssh -i ../insecure_keys/vagrant.private root@$client "timeout 3m rpm -e rear" | tee -a $LOGFILE
            ssh -i ../insecure_keys/vagrant.private root@$client "timeout 3m yum --showduplicates list rear" > /tmp/REAR-versions.$$
            REAR_VER=$( grep rear /tmp/REAR-versions.$$ | grep -v Snapshot | grep "${release_nr}-" | tail -1 | awk '{print $2}' )
            rm -f /tmp/REAR-versions.$$
            ssh -i ../insecure_keys/vagrant.private root@$client "timeout 3m yum --disableplugin=fastestmirror -y install rear-$REAR_VER" | tee -a $LOGFILE
            [[ $? -eq 1 ]] && Error "Could not install stable version rear-$REAR_VER"
            ;;
       (fedora*)
            ssh -i ../insecure_keys/vagrant.private root@$client "timeout 3m rpm -e rear" | tee -a $LOGFILE
            ssh -i ../insecure_keys/vagrant.private root@$client "timeout 3m dnf --showduplicates list rear" > /tmp/REAR-versions.$$
            REAR_VER=$( grep rear /tmp/REAR-versions.$$ | grep -v Snapshot | grep "${release_nr}-" | tail -1 | awk '{print $2}' )
            rm -f /tmp/REAR-versions.$$
            ssh -i ../insecure_keys/vagrant.private root@$client "timeout 3m dnf --disableplugin=fastestmirror -y install rear-$REAR_VER" | tee -a $LOGFILE
            [[ $? -eq 1 ]] && Error "Could not install stable version rear-$REAR_VER"
            ;;
        (sles*)
            ssh -i ../insecure_keys/vagrant.private root@$client "timeout 3m rpm -e rear" | tee -a $LOGFILE
            ssh -i ../insecure_keys/vagrant.private root@$client "timeout 3m zypper packages | grep rear | cut -d '|' -f 3,4" > /tmp/REAR-versions.$$
            REAR_VER=$( grep " rear" /tmp/REAR-versions.$$ | grep -v git | grep "${release_nr}-" | tail -1 | awk '{print $3}' )
            rm -f /tmp/REAR-versions.$$
            ssh -i ../insecure_keys/vagrant.private root@$client "timeout 3m zypper --non-interactive install rear-$REAR_VER" | tee -a $LOGFILE
            [[ $? -eq 1 ]] && Error "Could not install stable version rear-$REAR_VER"
            ;;
    esac

fi
LogPrint ""

# Option -f test will be executed on 'client' VM only (at least for now)
# Therefore, check if the test is an existing directory for the test we want
# TODO: remove this block and replace by a good set of inspec compliance controls
if [[ "$DO_TEST" = "y" ]] ; then
    # $test_dir contains the test we want to execute; first copy it to the client vm
    Log "Copying the Beaker tests onto the VM client"    
    echo "$(bold Copying the Beaker tests onto the VM client)"    
    scp -i ../insecure_keys/vagrant.private -r ../tests root@$client:/var/tmp | tee -a $LOGFILE
    # install rear-rhts and beakerlib
    Log "Install rear-rhts  and beakerlib packages required for the Beaker tests"
    echo "$(italic Install rear-rhts  and beakerlib packages required for the Beaker tests)"
    ssh -i ../insecure_keys/vagrant.private root@$client "timeout 3m yum --disableplugin=fastestmirror -y install rear-rhts beakerlib" | tee -a $LOGFILE
    # on the client vm all tests are available under /var/tmp/tests/
    LogPrint "Executing test $test_dir"
    LogPrint "---------------------------------"
    ssh -i ../insecure_keys/vagrant.private root@$client "cd /var/tmp/tests/$test_dir ; make" | tee -a $LOGFILE
    rc=$?
    [[ $rc -gt 0 ]] && Error "make command failed for test $test_dir"
    jFile=/$(ssh -i ../insecure_keys/vagrant.private root@$client 'tail -1 /mnt/testarea/current.log | cut -d/ -f2-' 2>/dev/null)
    # jFile=/var/tmp/beakerlib-lGspW7z/journal.txt for example
    [[ "$jFile" = "/" ]] && Error "Test results file not found on $client (check /mnt/testarea)"
    scp -i ../insecure_keys/vagrant.private root@$client:$jFile ../tests/$test_dir/test-results-of-$(date '+%Y%m%d') | tee -a $LOGFILE
    LogPrint "Saved the results as tests/$test_dir/test-results-of-$(date '+%Y%m%d')"
    exit 0
fi


# According the boot_method we can do different stuff now:
case $boot_method in
#~~~~~~~~~~~~~~~~~~
PXE)
####
    case $VAGRANT_DEFAULT_PROVIDER in
        virtualbox) 
                    case $(uname -s) in
                      Linux)  boot_server="10.0.2.2" ;;
                      Darwin) boot_server="192.168.33.1" ;;
                    esac
                    # with VirtualBox the TFTP boot path is under:
                    pxe_tftpboot_path=$( define_pxe_tftpboot_path )
                    # Linux: /root/.config/VirtualBox/TFTP
                    # OS/X:  /var/root/.config/VirtualBox/TFTP - however, to PXE boot on a Mac you need a
                    # symbolic link to /var/root/Library/VirtualBox/TFTP
                    case $(uname -s) in
                      Darwin) [[ ! -e /var/root/Library/VirtualBox/TFTP ]] && ln -s $pxe_tftpboot_path /var/root/Library/VirtualBox/TFTP ;;
                    esac
 
                    [[ ! -d "$pxe_tftpboot_path" ]] && mkdir -p -m 755 "$pxe_tftpboot_path" | tee -a $LOGFILE
                    [[ ! -d "$pxe_tftpboot_path/pxelinux.cfg" ]] && mkdir -p -m 755 "$pxe_tftpboot_path/pxelinux.cfg" | tee -a $LOGFILE
                    vagrant_host=$boot_server
                    ;;
        libvirt)   # we use the $server to PXE boot from
                   pxe_tftpboot_path=$( define_pxe_tftpboot_path )
                   ssh -i ../insecure_keys/vagrant.private root@$server "mkdir -p -m 755 $pxe_tftpboot_path/pxelinux.cfg" | tee -a $LOGFILE
                   ;;
    esac

    # Copy the ReaR config template to the client VM, but first we need to replace @server@ and @boot_server@ with the
    # real values defined with arguments given or use the default ones
    sed -e "s;@server@;$server;g" -e "s;@boot_server@;$boot_server;g" \
        -e "s;@pxe_tftpboot_path@;$pxe_tftpboot_path;g" < $REAR_CONFIG > /tmp/rear_config.$$
    # Append the TEST_LOG_DIR location to the rear config file
    echo "TEST_LOG_DIR_URL=nfs://${vagrant_host}${TEST_LOG_DIR}" >> /tmp/rear_config.$$
    Log "Configure rear on client to use OUTPUT=PXE method"
    echo "$(bold Configure rear on client to use $(green OUTPUT=PXE) method)"
    scp -i ../insecure_keys/vagrant.private /tmp/rear_config.$$ root@$client:/etc/rear/local.conf | tee -a $LOGFILE
    LogPrint ""

    LogPrint "Copy PXE post script to disable PXE booting after sucessful 'rear recover'"
    ssh -i ../insecure_keys/vagrant.private root@$client "mkdir -p -m 755 /usr/share/rear/wrapup/PXE/default" | tee -a $LOGFILE
    scp -i ../insecure_keys/vagrant.private ../rear-scripts/200_inject_default_boothd0_boot_method.sh root@$client:/usr/share/rear/wrapup/PXE/default/200_inject_default_boothd0_boot_method.sh | tee -a $LOGFILE

    ;;
#~~~~~~~~~~~~~~~~~~~~
ISO)
####
   #echo "$(red WARNING: Sorry 'not' yet completely tested by $PRGNAME)"
   case $VAGRANT_DEFAULT_PROVIDER in
       virtualbox) 
                   case $(uname -s) in
                     Linux)  boot_server="10.0.2.2" ;;
                     Darwin) boot_server="192.168.33.1" ;;
                   esac

                   pxe_tftpboot_path=$( define_pxe_tftpboot_path )
                   [[ ! -d "$pxe_tftpboot_path" ]] && mkdir -p -m 755 "$pxe_tftpboot_path" | tee -a $LOGFILE
                   [[ ! -d "$pxe_tftpboot_path/pxelinux.cfg" ]] && mkdir -p -m 755 "$pxe_tftpboot_path/pxelinux.cfg" | tee -a $LOGFILE
                   # ISO images are stored under /export/isos/client - we will make a soft link to it
                   #[[ ! -d /export/isos ]] && mkdir -p -m 755 /export/isos | tee -a $LOGFILE
                   [[ ! -d $pxe_tftpboot_path/isos ]] && mkdir -p -m 755 "$pxe_tftpboot_path/isos" | tee -a $LOGFILE
                   # in our pxelinux config file rear-client we will use this for the ISO menu
                   #[[ ! -h "$pxe_tftpboot_path/isos" ]] && ln -s /export/isos "$pxe_tftpboot_path/isos"
                   # we need memdisk to boot an ISO image
                   [[ -f /usr/share/syslinux/memdisk ]] && cp -p /usr/share/syslinux/memdisk "$pxe_tftpboot_path"
                   # we need chain.c32 as well
                   [[ -f /usr/share/syslinux/chain.c32 ]] && cp -p /usr/share/syslinux/chain.c32 "$pxe_tftpboot_path"
                   vagrant_host=$boot_server
                   ;;
       libvirt)    pxe_tftpboot_path=$( define_pxe_tftpboot_path )
                   boot_server="192.168.33.15"
                   ssh -i ../insecure_keys/vagrant.private root@$server "mkdir -p -m 755 $pxe_tftpboot_path/pxelinux.cfg" | tee -a $LOGFILE
                   ssh -i ../insecure_keys/vagrant.private root@$server "mkdir -p -m 755 $pxe_tftpboot_path/isos" | tee -a $LOGFILE
                   #ssh -i ../insecure_keys/vagrant.private root@$server "[[ ! -h "$pxe_tftpboot_path/isos" ]] && ln -s /export/isos $pxe_tftpboot_path/isos" | tee -a $LOGFILE
                   ssh -i ../insecure_keys/vagrant.private root@$server "[[ -f /usr/share/syslinux/memdisk ]] && cp -p /usr/share/syslinux/memdisk $pxe_tftpboot_path" | tee -a $LOGFILE
                   ssh -i ../insecure_keys/vagrant.private root@$server "[[ -f /usr/share/syslinux/chain.c32 ]] && cp -p /usr/share/syslinux/chain.c32 $pxe_tftpboot_path" | tee -a $LOGFILE
                   # vagrant_host is the default value
                   ;;
   esac

   # We expect that the REAR_CONFIG was an argument with this script
   sed -e "s/@server@/$server/g" -e "s/@boot_server@/$boot_server/g" \
       -e "s;@pxe_tftpboot_path@;$pxe_tftpboot_path;g" < $REAR_CONFIG > /tmp/rear_config.$$
   # Append the TEST_LOG_DIR location to the rear config file
   echo "TEST_LOG_DIR_URL=nfs://${vagrant_host}${TEST_LOG_DIR}" >> /tmp/rear_config.$$

   Log "Configure rear on client to use OUTPUT=ISO method"
   echo "$(bold Configure rear on client to use $(green OUTPUT=ISO) method)"
   scp -i ../insecure_keys/vagrant.private  /tmp/rear_config.$$ root@$client:/etc/rear/local.conf | tee -a $LOGFILE
   LogPrint ""
   # We need to check the OUTPUT_URL/BACKUP_URL paths on the server side; if paths do not exist create them
   if grep -q ^OUTPUT_URL /tmp/rear_config.$$ ; then
       url=$( grep ^OUTPUT_URL /tmp/rear_config.$$ | cut -d= -f 2 )
       url_without_scheme=${url#*//}
       my_path="/${url_without_scheme#*/}"
       my_server="${url_without_scheme%%/*}"
       if [[ "$my_server" = "$boot_server" ]] ; then
           mkdir -m 755 -p $my_path
       else
           ssh -i ../insecure_keys/vagrant.private root@$my_server "mkdir -p -m 755 $my_path" | tee -a $LOGFILE
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
           ssh -i ../insecure_keys/vagrant.private root@$my_server "mkdir -p -m 755 $my_path" | tee -a $LOGFILE
       fi
   fi
   ssh -i ../insecure_keys/vagrant.private root@$client "mkdir -p -m 755 /usr/share/rear/wrapup/ISO/default" | tee -a $LOGFILE
   scp -i ../insecure_keys/vagrant.private ../rear-scripts/200_inject_default_boothd0_boot_method.sh root@$client:/usr/share/rear/wrapup/ISO/default/200_inject_default_boothd0_boot_method.sh | tee -a $LOGFILE

   ;;
#~~~~~~~~~~~~~~~~~~~~
*)
    Error "Boot method $boot_method 'not' yet foreseen by $PRGNAME"
    ;;
esac

# remove the temporary ReaR config file from this host
rm -f /tmp/rear_config.$$

#
# Before running ReaR we need to copy one more script to have the recover log to be copied onto TEST_LOG_DIR
# Important note: TEST_LOG_DIR will be mounted by the recover VM so make sure it is exported by the host/hypervisor
# That script will run at the end of a 'rear mkbackup' or 'rear recover' and copy the logfile (via NFS) to TEST_LOG_DIR
# We will copy the script twice to:
#  - /usr/share/rear/wrapup/default/995_store_recover_log_on_test_log_dir.sh
#  - /usr/share/rear/backup/default/995_store_recover_log_on_test_log_dir.sh
LogPrint ""
LogPrint "Copy 995_store_recover_log_on_test_log_dir.sh to the client VM"
# the backup area is only executed by the 'backup' workflow - runs on the client VM:
scp -i ../insecure_keys/vagrant.private ../rear-scripts/995_store_recover_log_on_test_log_dir.sh root@$client:/usr/share/rear/backup/default/995_store_recover_log_on_test_log_dir.sh | tee -a $LOGFILE

# the wrapup area is only executed by the 'recover' workflow - runs on the recover VM:
scp -i ../insecure_keys/vagrant.private ../rear-scripts/995_store_recover_log_on_test_log_dir.sh root@$client:/usr/share/rear/wrapup/default/995_store_recover_log_on_test_log_dir.sh | tee -a $LOGFILE

# copy a script for SLES11 to remove the 70-persistent-net.rules file on rescue image - issue #59
scp -i ../insecure_keys/vagrant.private ../rear-scripts/700_remove_persistent_net_rules.sh root@$client:/usr/share/rear/build/SUSE_LINUX/700_remove_persistent_net_rules.sh | tee -a $LOGFILE


LogPrint ""
Log "ReaR version that will be tested is:"
echo "$(bold ReaR version that will be tested is:)"
ssh -i ../insecure_keys/vagrant.private root@$client "rear -V" | tee -a $LOGFILE
LogPrint "
"

Log "Content of /etc/rear/local.conf is:"
echo "$(bold Content of /etc/rear/local.conf is:)"
ssh -i ../insecure_keys/vagrant.private root@$client "grep -v \# /etc/rear/local.conf" | tee -a $LOGFILE
LogPrint "
"

Log "Run 'rear -v mkbackup'"
echo "$(bold Run 'rear -v mkbackup')"
ssh -i ../insecure_keys/vagrant.private root@$client "rear -v mkbackup" | tee -a $LOGFILE
# To capture errors we have to grab for ERROR keyword in the rear.log file (on the client) and the output is checked
# once more to really capture the ERROR code (rc=0 means ERROR in this case)
ssh -i ../insecure_keys/vagrant.private root@$client "tail -25 /var/log/rear/rear-client.log | grep ERROR" | grep -q ERROR
rc=$?

LogPrint "
"
if [[ $rc -eq 0 ]] ; then
    Log "Please check the rear logging /var/log/rear/rear-client.log"
    echo "$(red Please check the rear logging /var/log/rear/rear-client.log)"
    LogPrint "The last 25 lines are:"
    ssh -i ../insecure_keys/vagrant.private root@$client "tail -25 /var/log/rear/rear-client.log" | tee -a $LOGFILE
    LogPrint ""
    Error "Check yourself via 'vagrant ssh client'"
else
    Log "The rear mkbackup was successful"
    echo "$(bold $(green The rear mkbackup was successful))"
fi
LogPrint "
"

# According the boot_method we can do different stuff now:
case $boot_method in
    PXE)
    ####

    # For PXE access we have to make sure that on the server the client area is readable for others
    # In my ~/.ssh/config file I defined the line "UserKnownHostsFile /dev/null" to avoid issues
    # with duplicate host keys (after re-installing from scratch the VMs)

    Log "Make client area readable for others on PXE boot server $boot_server"
    echo "$(bold Make client area readable for others on PXE boot server $(green $boot_server))"
    case $VAGRANT_DEFAULT_PROVIDER in
       virtualbox) chmod -R 755 "$pxe_tftpboot_path"/client
                   ;;
       libvirt)    ssh -i ../insecure_keys/vagrant.private root@$boot_server "chmod -R 755 $pxe_tftpboot_path/client" | tee -a $LOGFILE
                   ;;
    esac
    LogPrint ""
    ;;

    ISO)
    ####
    # Todo: clean up the PXE area to avoid PXE booting?
    pxe_tftpboot_path=$( define_pxe_tftpboot_path )
    case $VAGRANT_DEFAULT_PROVIDER in
       virtualbox) [[ ! -d "$pxe_tftpboot_path"/client ]] && mkdir -p -m 755 "$pxe_tftpboot_path"/client
                   chmod 755 "$pxe_tftpboot_path"/client
                   if [[ -d $pxe_tftpboot_path/isos/client ]] ; then
                       chmod 755  $pxe_tftpboot_path/isos/client
                       chmod 644  $pxe_tftpboot_path/isos/client/*.iso
                   else
                       #mkdir -p -m 755 /export/isos/client
                       Error "$pxe_tftpboot_path/isos/client not found"
                   fi
                   # the PXE entry must be created after the rear mkbackup has finished as the pxe cfg file is recreated
                   LogPrint "Copy PXE configuration entry to pxelinux.cfg to enable ISO boot menu entry"
                   # we overwrite any existing pxelinux.cfg file with our template pxelinux-cfg-with-iso-entry
                   cat ../templates/pxelinux-cfg-with-iso-entry > "$pxe_tftpboot_path/pxelinux.cfg/rear-client"
                   [[ ! -h "$pxe_tftpboot_path/pxelinux.cfg/default" ]] && ln -s $pxe_tftpboot_path/pxelinux.cfg/rear-client $pxe_tftpboot_path/pxelinux.cfg/default | tee -a $LOGFILE
                   ;;
       libvirt)    ssh -i ../insecure_keys/vagrant.private root@$boot_server "chmod -R 755 $pxe_tftpboot_path/client" | tee -a $LOGFILE
                   ssh -i ../insecure_keys/vagrant.private root@$boot_server "chmod 755 $pxe_tftpboot_path/isos/client" | tee -a $LOGFILE
                   ssh -i ../insecure_keys/vagrant.private root@$boot_server "chmod 644  $pxe_tftpboot_path/isos/client/*.iso" | tee -a $LOGFILE
                   scp -i ../insecure_keys/vagrant.private ../templates/pxelinux-cfg-with-iso-entry root@$boot_server:"$pxe_tftpboot_path/pxelinux.cfg/rear-client" | tee -a $LOGFILE
                   ssh -i ../insecure_keys/vagrant.private root@$boot_server "ln -s $pxe_tftpboot_path/pxelinux.cfg/rear-client $pxe_tftpboot_path/pxelinux.cfg/default" | tee -a $LOGFILE
                   ;;
    esac

    ;;

esac

# Before halting the client VM run some compliance checks on the client and save the output under $TEST_LOG_DIR
if test $(which inspec 2>/dev/null) ; then
    if ! test $(which dos2unix 2>/dev/null) ; then
        echo "$(bold WARNING: Package $(green 'dos2unix') is missing. $(red InSpec needs it for proper output))"
    fi
    inspec exec ../inspec/compliance-checks -i ../insecure_keys/vagrant.private -t ssh://root@client | dos2unix -f | tee -a $TEST_LOG_DIR/inspec_results_client_before_recovery
fi


LogPrint "
"
Log "Halting the client VM before doing the recovery"
echo "$(bold Halting the client VM $(italic before doing the recovery))"
LogPrint "Recover VM will use the client IP address after it has been fully restored"
LogPrint ""
vagrant halt client | tee -a $LOGFILE
LogPrint ""

#############################################################################################################################

# For issue #15 with virtualbox and "recover: Warning: Authentication failure. Retrying" we need to copy
# the client private key to the recover directory (made no difference)
case $VAGRANT_DEFAULT_PROVIDER in
    virtualbox) 
        if [[ -f .vagrant/machines/client/virtualbox/private_key ]] ; then
            ##cp .vagrant/machines/client/virtualbox/private_key .vagrant/machines/recover/virtualbox/private_key
            ##echo "Copied private key of client VB to recover VB config area"
            :
        fi
        ;;
esac

Log "Starting the recover VM"
echo "$(bold Starting the recover VM)"
vagrant up recover | tee -a $LOGFILE

type -p vncviewer >/dev/null
rc=$?
if [[ $rc -ne 0 ]] ; then
    LogPrint "To see what happens install vncviewer, or use 'vagrant ssh recover'"
    LogPrint ""
else
    LogPrint "Script will pauze until you disconnect from the 'vncviewer' application"
    LogPrint ""
    vncviewer 127.0.0.1:5993 
fi

# Go back to original starting directory
cd $Current_dir

# exit message
echo "$(bold The log files are saved under $(red $TEST_LOG_DIR))"
echo
if test $(which inspec 2>/dev/null) ; then
    echo "$(bold You might consider to run, when the client VM was recovered, the following command:)"
    echo "inspec exec ./inspec/compliance-checks -i ./insecure_keys/vagrant.private -t ssh://root@client | dos2unix -f | tee $TEST_LOG_DIR/inspec_results_client_after_recovery"
fi

exit 0
