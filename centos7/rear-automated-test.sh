#!/bin/bash
#
# rear-automated-test.sh script

echo "
+--------------------------------------------------+
|    Relax-and-Recover Automated Testing script    |
+--------------------------------------------------+

Author: Gratien D'haese
Copyright: GPL v3

"

client="192.168.33.10"
server="192.168.33.15"

if [[ $(id -u) -ne 0 ]] ; then
    echo "Please run this script as root"
    exit 1
fi

# start up and client server vagrant VMs (the recover VM stays down)
echo "Bringing up the vagrant VMs client and server"
vagrant up
echo
echo "Sleep for 5 seconds"
sleep 5

echo
vagrant status

echo
echo "Doing ping tests to VMs client and server"
ping $client -c 1 >/dev/null 2>&1
rc=$?

if [[ $rc -ne 0 ]] ; then
    echo "VM $client is not pingable - please investigate why"
    exit 1
else
    echo "VM $client is up and running - ping test OK"
fi

ping $server  -c 1 >/dev/null 2>&1
rc=$?

if [[ $rc -ne 0 ]] ; then
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

echo "Configure rear on client to use OUTPUT=PXE method"
ssh -i ../insecure_keys/vagrant.private root@$client "cp -f /usr/share/rear/conf/examples/PXE-booting-example-with-URL-style.conf /etc/rear/local.conf"
echo

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

# For PXE access we have to make sure that on the server the client area is readable for others
echo "Make client area readable for others on server"
ssh -i ../insecure_keys/vagrant.private root@$server "chmod 755 /export/nfs/tftpboot/client"
echo

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
