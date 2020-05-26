function IsNotPingable () {
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

function findUser () {
    thisPID=$$
    origUser=$(whoami)
    thisUser=$origUser

    while [ "$thisUser" = "$origUser" ]
    do
        ARR=($(ps h -p$thisPID -ouser,ppid | tail -1) )   # tail -1 required for MacOS
        thisUser="${ARR[0]}"
        myPPid="${ARR[1]}"
        thisPID=$myPPid
    done

    case $(uname -s) in
        Linux) getent passwd "$thisUser" | cut -d: -f1 ;;
        Darwin) echo "$thisUser" ;;  # on MacOS we could use dscl
        *) grep "^$thisUser" /etc/passwd | cut -d: -f1 ;;
    esac
}

function helpMsg () {
    cat <<eof
************************************************
** Relax-and-Recover (ReaR) Automated Testing **
************************************************
Usage: $PRGNAME [-d distro] [-b <boot method>] [-s <stable rear version>] [-p provider] [-c rear-config-file.conf] -vh
        -d: The distribution to use for this automated test (default: $distro)
        -b: The boot method to use by our automated test (default: $boot_method)
        -s: The <stable rear version> is the specific version we want to test, e.g. 2.3 (default: <empty> )
        -p: The vagrant <provider> to use (default: $VAGRANT_DEFAULT_PROVIDER)
        -c: The ReaR config file we want to use with this test (default: PXE-booting-with-URL-style.conf)
        -l: The ReaR test logs top directory (default: $LOG_DIR)
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
eof
}

function define_pxe_tftpboot_path () {
    # pxe_tftpboot_path path is need by boot methods PXE and ISO
    # PXE to fill up the client PXE boot configs
    # ISO to remove to client PXE configs (otherwise we boot from PXE or boothd0)
    case $VAGRANT_DEFAULT_PROVIDER in
        virtualbox)
                    # with VirtualBox the TFTP boot path is under:
                    pxe_tftpboot_path="$root_home/.config/VirtualBox/TFTP"
                    ;;
        libvirt)
                    # has already been defined in the default settings
                    pxe_tftpboot_path="/export/nfs/tftpboot"
                    ;;
    esac
    echo $pxe_tftpboot_path
}

function os_release () {
    # purpose of this function is to return a string with OS ID which is
    # typically retrieved from /etc/os-release (on modern OSes)
    # Not used for the moment
    typeset ID=""
    if [[ -f /etc/os-release ]] ; then
        ID=$( grep ^ID= /etc/os-release | cut -d= -f2 | sed -e 's/"//g' )
    elif [[ -f /etc/system-release ]]; then
        ID=$( awk '{print $1}' /etc/system-release )
    else
        ID="unkown"
    fi
    echo "$ID"
}

# Check if any of the arguments is executable (logical OR condition).
# Using plain "type" without any option because has_binary is intended
# to know if there is a program that one can call regardless if it is
# an alias, builtin, function, or a disk file that would be executed
function has_binary () {
    for bin in $@ ; do
        # Suppress success output via stdout (but keep failure output via stderr):
        if type $bin 1>/dev/null ; then
            return 0
        fi
    done
    return 1
}

# Get the name of the disk file that would be executed.
# In contrast to "type -p" that returns nothing for an alias, builtin, or function,
# "type -P" forces a PATH search for each NAME, even if it is an alias, builtin,
# or function, and returns the name of the disk file that would be executed
function get_path () {
    type -P $1
}

