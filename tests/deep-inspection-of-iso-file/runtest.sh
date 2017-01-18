#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/rear/Sanity/deep-inspection-of-iso-file
#   Description: This is initial test for new component rear. There is created basic backup and checked created iso file and saved system configuration. This is test for BZ#1059196 and BZ#981637.
#   Author: Tereza Cerna <tcerna@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2015 Red Hat, Inc.
#
#   This program is free software: you can redistribute it and/or
#   modify it under the terms of the GNU General Public License as
#   published by the Free Software Foundation, either version 2 of
#   the License, or (at your option) any later version.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE.  See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program. If not, see http://www.gnu.org/licenses/.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include Beaker environment
. /usr/bin/rhts-environment.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE_REAR="rear"
PACKAGE_BEAKERLIB="beakerlib"

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm $PACKAGE_REAR
        rlAssertRpm $PACKAGE_BEAKERLIB
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        cp root.files $TmpDir/.
        rlRun "pushd $TmpDir"
        rlFileBackup /etc/rear/local.conf
        rlFileBackup /etc/passwd
        echo "" > /etc/rear/local.conf
    rlPhaseEnd

    rlPhaseStartTest "Run REAR and check ISO file"
        rlRun "rear -v mkrescue > rear.out"
        cat rear.out
        ISO=`cat rear.out | grep "Wrote ISO" | awk '{ print $4 }'`
        echo $ISO
        rlRun "[ -z $ISO ]" 1
        rlRun "file $ISO | grep RELAXRECOVER"
        rlRun "isoinfo -d -i $ISO | grep RELAXRECOVER"
    rlPhaseEnd

    rlPhaseStartTest "Check backup in iso"
        mkdir rear.files
        rlRun "mount -oloop $ISO rear.files"
        INITRD=`find rear.files/ | grep initrd.cgz`
        rlRun "cp $INITRD ."
        mv initrd.cgz initrd.gz
        rlRun "gunzip initrd.gz"
        rlRun "file initrd | grep \"cpio archive\""
        mkdir initrd.out
        cd initrd.out
        rlRun "cpio -idv < ../initrd"
        for i in `cat ../root.files`; do
            test -e /$i
            if [ $? == 0 ]; then
                rlRun "test -e $i"
            fi
        done
        rlRun "test -e init"
        rlRun "test -e run"
        cd ..
        rlRun "umount rear.files"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlFileRestore
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

