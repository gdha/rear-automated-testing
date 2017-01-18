#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/rear/Sanity/make-backuponly-and-check-files
#   Description: Rear creates only backup and check that only tar.gz file was created.
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
        rlFileBackup "/etc/exports"
        rlFileBackup "/etc/rear/local.conf"
    rlPhaseEnd


    rlPhaseStartSetup "Create NFS server on localhost"
        rlRun "mkdir /mnt/rear"
        rlRun "echo \"/mnt/rear    localhost(rw,sync,no_root_squash)\" > /etc/exports"
        rlRun "cat /etc/exports"
        rlRun "exportfs -r"
        rlRun "service nfs restart"
    rlPhaseEnd


    rlPhaseStartSetup "Create NFS client on localhost for rear"
        rlRun "echo \"OUTPUT=ISO
BACKUP=NETFS
BACKUP_URL="nfs://localhost/mnt/rear/"
GRUB_RESCUE=1
\" > /etc/rear/local.conf"
        rlRun "cat /etc/rear/local.conf"
    rlPhaseEnd


    rlPhaseStartTest "Run REAR backuponly"
        rlRun "rear -v mkbackuponly > output"
        rlRun "cat output"
    rlPhaseEnd


    rlPhaseStartTest "Check output of rear"
        # ISO image should not be created
        rlRun "grep \"Making ISO image\" output" 1
        rlRun "grep -E 'Wrote ISO [iI]mage[:]* /var/lib/rear.*.iso.*' output" 1
        # tar.gz should be created
        rlRun "grep -E \"Creating tar archive '/tmp/rear..*/backup.tar.gz'\" output" 0
        rlRun "grep \"Archived [0-9]*.*\" output" 0
    rlPhaseEnd


    rlPhaseStartTest "Check directory /mnt/rear"
        # ISO image should not be created
        rlRun "find /mnt/rear | grep -E \"rear-.*.iso\"" 1
        # tar.gz should be created
        rlRun "find /mnt/rear | grep \"backup.tar.gz\"" 0
    rlPhaseEnd


    rlPhaseStartCleanup
        rlFileRestore
        rm -rf /mnt/rear
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd

rlJournalPrintText
rlJournalEnd
