#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/rear/Sanity/check-changed-disk-layout
#   Description: Check changed disk layout with parameter checklayout.
#   Author: Tereza Cerna <tcerna@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2016 Red Hat, Inc.
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
        rlRun "pushd $TmpDir"
    rlPhaseEnd

    rlPhaseStartTest "Test option rear checklayout"
        
        # Run rear checklayout
        rlRun "rear -v checklayout > output" 0
        cat output
        rlRun "grep 'Disk layout is identical.' output" 0
        
        # Switch off all swap
        rlAssertGreaterOrEqual "There should be at least one swap disk" `lvs | wc -l` 2
        lvs
        rlRun "swapoff -a" 0 "Stop all swap disks"
        
        # Run rear checklayout
        rlRun "rear -v checklayout > output" 1
        cat output
        rlRun "grep 'Disk layout has changed.' output" 0
        
        # Switch on all swap
        rlRun "swapon -a" 0 "Start all swap disks"
        
        # Run rear checklayout
        rlRun "rear -v checklayout > output" 0
        cat output
        rlRun "grep 'Disk layout is identical.' output" 0

    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
