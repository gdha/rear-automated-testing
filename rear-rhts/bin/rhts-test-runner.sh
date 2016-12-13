#!/bin/bash
export PATH=$PATH:/usr/kerberos/sbin:/usr/kerberos/bin:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/usr/X11R6/bin:/root/bin

function sizeof() {
    # sizeof FILE -- returns FILE's size in bytes
    if [[ -z $1 ]]; then
        return 1
    fi
    stat --format="%s" $1
}

function diffat() {
    # diffat FILE1 FILE2 -- returns first offset where FILE1 and FILE2 differ
    if [[ -z $1 || -z $2 ]]; then
        return 1
    fi
    local file1=$1 file2=$2
    shift 2
    local data=$(cmp $file1 $file2 2>&1)
    if echo "$data" | grep '^cmp: EOF on ' &>/dev/null; then
        # cmp: EOF on FILE
        sizeof $(echo "$data" | sed -ne 's/^cmp: EOF on \(.*\)/\1/p')
    elif echo "$data" | grep 'differ: byte ' &>/dev/null; then
        # FILE1 FILE2 differ: byte 6, line 1
        expr $(echo "$data" | sed -ne 's/.* differ: byte \([1-9][0-9]*\), line \([1-9][0-9]*\)$/\1/p') - 1
    else
        return 1
    fi
}

function submit_testout() {
    local start=0
    declare -i start=0
    if [[ ! -f /mnt/testarea/TESTOUT.log ]]; then
        return 0
    fi
    mkdir /mnt/testarea/rhts &>/dev/null
    # the file is still growing: make a copy first
    cp /mnt/testarea/TESTOUT.log /mnt/testarea/rhts/TESTOUT.log
    if [[ -f /mnt/testarea/_TESTOUT.log ]]; then
      if cmp -s /mnt/testarea/rhts/TESTOUT.log /mnt/testarea/_TESTOUT.log; then
          # files do not differ - nothing to upload
          return 0
      fi
      start=$(diffat /mnt/testarea/rhts/TESTOUT.log /mnt/testarea/_TESTOUT.log)
    fi
    rhts-submit-log -l /mnt/testarea/rhts/TESTOUT.log --start="$start"
    mv -f /mnt/testarea/rhts/TESTOUT.log /mnt/testarea/_TESTOUT.log
}

function report_finish {
    logger -s "$0 report_finish start..."
    # upload the STDOUT/STDERR of the just run test
    submit_testout
    # Clear the log
    > /mnt/testarea/TESTOUT.log
    rm -f /mnt/testarea/_TESTOUT.log
    [ -n "$OUTPUTFILE" ] && cat $OUTPUTFILE
    export TESTORDER=$(expr $TESTORDER + 1)
    rhts-sync-set -s DONE
    rhts-sync-block -s DONE $SERVERS $CLIENTS $DRIVER
    rhts-test-update $RESULT_SERVER $TESTID finish

    /bin/touch  /var/cache/rhts/$TESTID/done

    #Restore any files tagged by the test..
    rhts-restore

    #Clear audit.log* to prevent any future denails from being reported again
    for log in /var/log/audit/*; do
        > $log
    done

    logger -s "$0 report_finish stop..."
}

function get_hooks() {
    if [[ -z $1 ]]; then
        echo "ERROR: HOOK is not defined." >&2
        echo "Usage: hooks HOOK" >&2
        return 1
    fi
    for path in $HOME/.rhts/hooks ${RHTSDIR:-"/usr/share/rhts"}/hooks; do
        if [[ -d $path ]]; then
            for f in $path/$1/*; do
                if [[ -x $f ]]; then
                    echo $(basename $f) $f
                fi
            done
        fi
    done | sort | awk '{ print $2 }'
}

if [ -z "$TEST" ]; then
    echo "TEST is not defined"
    exit 1
fi
if [ -z "$TESTRPMNAME" ]; then
    echo "TESTRPMNAME is not defined"
    exit 1
fi
if [ -z "$TESTPATH" ]; then
    echo "TESTPATH is not defined"
    exit 1
fi
if [ -z "$KILLTIME" ]; then
    echo "KILLTIME is not defined"
    exit 1
fi
if [ -z "$RESULT_SERVER" ]; then
    echo "RESULT_SERVER is not defined"
    exit 1
fi
if [ -z "$HOSTNAME" ]; then
    echo "HOSTNAME is not defined"
    exit 1
fi
if [ -z "$JOBID" ]; then
    echo "JOBID is not defined"
    exit 1
fi
if [ -z "$TESTID" ]; then
    echo "TESTID is not defined"
    exit 1
fi
if [ -z "$ARCH" ]; then
    echo "ARCH is not defined"
    exit 1
fi

TESTRPMNAME=$(echo $TESTRPMNAME | sed -e 's/\.rpm$//')

if [ -n "$KILLTIMEOVERRIDE" ]; then
    KILLTIME=$KILLTIMEOVERRIDE
fi

UPTIMEKILL=$(expr $KILLTIME + $(cat /proc/uptime | awk -F. {'print $1'}))
if [ -e "/var/cache/rhts/$TESTID/done" ]; then
    echo "$TESTID:$TEST has already run.."
    # We've already run...
    exit 0
fi

if [ ! -e "/var/cache/rhts/$TESTID/reboot" ]; then
    mkdir -p /var/cache/rhts/$TESTID
    export REBOOTCOUNT=0
    echo 1 > /var/cache/rhts/$TESTID/reboot
else
    export REBOOTCOUNT=$(cat /var/cache/rhts/$TESTID/reboot)
    echo $(expr $REBOOTCOUNT + 1) > /var/cache/rhts/$TESTID/reboot
fi

. /usr/bin/rhts_environment.sh
OUTPUTFILE=`mktemp /mnt/testarea/tmp.XXXXXX`
# Don't export our OUTPUTFILE to the test were running.
export -n OUTPUTFILE

if [ ! -e "$TESTPATH/Makefile" ] && [ ! -e "$TESTPATH/runtest.sh" ]; then
   INSTALLTESTRPMNAME=$(echo $TESTRPMNAME | sed -e 's/\.rpm$//')
   # Older yum seems to have busted cache logic.
   /bin/rm -rf /var/cache/yum/rhts-noarch
   yum --disablerepo=* --enablerepo=rhts-noarch -y install $INSTALLTESTRPMNAME >> $OUTPUTFILE 2>&1
   if [ $? -ne 0 ]; then
       report_result $TEST/YUM Warn
       report_finish
       exit 1
   fi
fi

export PACKAGENAME=$(/bin/rpm -q --qf '%{name}' $TESTRPMNAME)
# Add 30 minutes to the lab watchdog controller
LABWATCHDOG=$(expr $KILLTIME + 1800)

# Only update watchdog on first time into test.  If we have rebooted then skip
if [ $REBOOTCOUNT -eq 0 ]; then
    logger -s "$0 rhts-extend $LAB_CONTROLLER $TESTID $LABWATCHDOG"
    rhts-extend $LAB_CONTROLLER $TESTID $LABWATCHDOG
    logger -s "$0 rhts-test-checkin $RESULT_SERVER $HOSTNAME $JOBID $TEST $LABWATCHDOG $TESTID"
    rhts-test-checkin $RESULT_SERVER $HOSTNAME $JOBID $TEST $LABWATCHDOG $TESTID || exit 1
    logger -s "$0 rhts-test-update $RESULT_SERVER $TESTID start $RPACKAGES $PACKAGENAME"
    rhts-test-update $RESULT_SERVER $TESTID start $RPACKAGES $PACKAGENAME
fi

pushd $TESTPATH
if [ "$?" -ne "0" ]; then
    echo "Unable to change working directory to $TESTPATH" >> $OUTPUTFILE
    logger -s "$0 Unable to change working directory to $TESTPATH"
    report_result $TEST/CHANGEDIR Warn
else
    if [ -e "Makefile" ]; then
        # Write pending changes to disk for case of crash early in the test.
        # This can confuse REBOOTCOUNT and result in infinite loop.
        sync
        set -m
        make run >>/mnt/testarea/TESTOUT.log 2>&1 &
        pid=$!
        while ps -p "$pid" | grep -q "$pid";do
            uptime=$(cat /proc/uptime| awk -F. {'print $1'})
            # Write something every minute to show we are alive...
            if [ $(expr $uptime % 60) = 0 ]; then
                timestamp=$(/bin/date '+%F %T')
                logger -s "$timestamp $0 $UPTIMEKILL $uptime hearbeat..."
            fi
            # Upload log every 5 minutes
            if [ $(expr $uptime % ${UPLOAD_SECONDS:-300}) = 0 ]; then
                # upload the STDOUT/STDERR of the currently running test
                timestamp=$(/bin/date '+%F %T')
		echo -e "\nMARK-LWD-LOOP -- $timestamp --" >> /mnt/testarea/TESTOUT.log
                submit_testout
            fi
            # Sleep for a specified time then wake up to kill the child process.
            if [ "$uptime" -ge "$UPTIMEKILL" ]; then
		# Try and get some system data why the system LWD.
                # run watchdog hooks:
                for f in $(get_hooks watchdog); do
                    echo "Watchdog: running '$f'..." >> /mnt/testarea/TESTOUT.log
                    TASK_PID=$pid "$f" watchdog >> /mnt/testarea/TESTOUT.log 2>&1
                done
		#  Before we kill the processes.
		rhts-system-info
                if ! ps -p "$pid" | grep -q "$pid"; then
                    echo "It took a bit longer but the task '$pid' has finished at last..."
                    break
                fi
                timestamp=$(/bin/date '+%F %T')
		echo "kill $pid -- $timestamp --" >> /mnt/testarea/TESTOUT.log
		kill -15 -"$pid"
		rc=$?
		if [ $rc -gt 0 ]; then
		    echo "Failed to kill $pid" >> /mnt/testarea/TESTOUT.log
		else
		    echo "Succesfully killed $pid" >> /mnt/testarea/TESTOUT.log
                fi
                echo "$UPTIMEKILL $KILLTIME"-second timeout expires, kill pgrp "$pid" >>$OUTPUTFILE
                logger -s "$0 $UPTIMEKILL $KILLTIME-second timeout expires, kill pgrp $pid"
                report_result $TEST/LOCALWATCHDOG Warn
		rhts-submit-log -l /var/log/messages
		# Upload any logs the user may want
		if [ -e $TESTPATH/logs2get ]; then
		    for l in `cat $TESTPATH/logs2get`; do
		        rhts-submit-log -l $l
		    done
		fi
                # Upload $OUTPUTFILE from the test that was aborted.
		if [ -h /mnt/testarea/current.log ]; then
		    rhts-submit-log -l /mnt/testarea/current.log
		fi
                report_finish
		# If local watchdog triggers we reboot to attempt to get things
		# in a sane state.
		rhts-reboot
                exit 1
            fi
	    sleep 1
	done
	jobsl=$(jobs -l)
	status=$(echo $jobsl| awk '{print $3}')
        echo jobsl = $jobsl >> $OUTPUTFILE
        echo status = $status >> $OUTPUTFILE
	if [ "$status" != "Done" ]; then
	    # Exited with non-zero status
	    report_result $TEST/RUN Warn
            report_finish
            exit 1
        fi
        report_finish
        exit 0
    else
        echo "Makefile doesn't exist" >>$OUTPUTFILE
        report_result $TEST/MAKEFILE Warn
    fi
fi
popd

report_finish
