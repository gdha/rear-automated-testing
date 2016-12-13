#!/bin/bash
#
# Copyright (c) 2006 Red Hat, Inc.
#
# This program is free software: you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation, either version 2 of
# the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be
# useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
# PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see http://www.gnu.org/licenses/.
#
# Authors: Bill Peck, Arjan van de Ven, Paul Sutherland

if [ -z "$OUTPUTFILE" ]; then
        export OUTPUTFILE=`mktemp /mnt/testarea/tmp.XXXXXX`
fi

if [ -z "$TESTPATH" ]; then
   TESTVERSION="developer"
else
   if [ -e "$TESTPATH/runtest.sh" ]; then
      TESTVERSION=$(rpm -qf $TESTPATH/runtest.sh)
   fi
fi

if [ -z "$HOSTNAME" ]; then
   HOSTNAME=$(hostname)
fi 

if [ -z "$ARCH" ]; then
        ARCH=$(uname -i)
fi

if [ -z "$FAMILY" ]; then
	FAMILY=$(cat /etc/redhat-release | sed -e 's/\(.*\)release\s\([0-9]*\).*/\1\2/; s/\s//g')
fi

#Set to "+no_avc_check" in order to not report AVC messages to rhts
if [ -z "$AVC_ERROR" ]; then
    export AVC_ERROR=`mktemp /mnt/testarea/tmp.XXXXXX`
    touch $AVC_ERROR
fi
# backup, in case user overrides AVC_ERROR variable for single result
export AVC_ERROR_FILE="$AVC_ERROR"

touch $OUTPUTFILE

#If we have rebooted we restore certain ENV variables from before..
if [ -e "/var/cache/rhts/$TESTID/ENV" ]; then
    . /var/cache/rhts/$TESTID/ENV
fi

# Set a "well known" log name, so if the localwatchdog triggers
#  we can still file OUTPUTFILE and get some results.
if [ -h /mnt/testarea/current.log ]; then
        ln -sf $OUTPUTFILE /mnt/testarea/current.log
else
        ln -s $OUTPUTFILE /mnt/testarea/current.log
fi

# this file is for sourcing in rhts test scripts

function report_result {
	rhts-report-result "$1" "$2" "$OUTPUTFILE" "$3"
}

function runuser_ {
	$(which runuser 2>/dev/null || which /sbin/runuser 2>/dev/null || echo /bin/su) "$@"
}

function runas_ {
	local user=$1 cmd=$2
	if [ -n "$user" ]; then
		echo "As $user: "
		HOME=$(eval "echo ~$user") LOGNAME=$user USER=$user runuser_ -m -c "$cmd" $user
	else
		echo "As $(whoami): "
		$cmd
	fi
}

#
# Do a startup test of a program
# Assumption is that the program will wait for user input so we'll
# kill it after 15 seconds
#
function startup_test {

	wasrunning=`pidof Xvfb`

	if [ "0$wasrunning" -eq "0" ]; then
        	Xvfb :1 -screen 0 1600x1200x24 -fbdir /mnt/testarea &
		sleep 3
        	export DISPLAY=:1
	fi
        
	ulimit -c unlimited
        rm -rf core*
        
        export MALLOC_PERTURB_=$(($RANDOM % 256))
        
	rhts-timed-test.sh 15 $1 $2 $3 $4 &> $OUTPUTFILE

	grep -q "Gtk-CRITICAL" $OUTPUTFILE
	if [ "$?" -eq "0" ]; then
		result=WARN
	fi                          
	
	which=$(which $1)
	if [ "$?" -eq "0" ]; then
		file $which | grep -q ELF
		if [ "$?" -eq "0" ]; then
			ldd $which | grep -q "=> not found"
			if [ "$?" -eq "0" ]; then
				ldd $which >> $OUTPUTFILE
				result=FAIL
			fi
		fi
	else
		result=FAIL
		echo "$1 is not found" >> $OUTPUTFILE
	fi
                          
	value=`ls core* | wc -l`
	if [ "$value" -ne "0" ]; then
 		result=FAIL
	fi
	
        ulimit -c 0
                          
        if [ "0$wasrunning" -eq "0" ]; then
        	kill `pidof Xvfb`
        fi
}


