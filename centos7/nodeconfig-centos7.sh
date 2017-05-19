#!/bin/bash
# nodeconfig-centos7.sh script
# goto the / directory (to avoid errors like - could not change directory to "/home/vagrant"
cd /

case $(hostname) in

client*)
#######
echo "Running client only commands:"
# In order to run the tests (from RHEL) we need rear-rhts and beakerlib software
# rear-rhts is customized package from the obsolete rhts package, but the tests
# scripts seem to need it
#yum install -y rear-rhts beakerlib
;;
# end of client specific code
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

server*) 
#######
echo "Running server only commands:"
#systemctl start smb nmb 
#systemctl enable smb nmb 
#setsebool -P samba_enable_home_dirs on 
#restorecon -R /home/vagrant
# adding user vagrant into smb passwd file with passwd vagrant
#printf "vagrant\nvagrant\n" | smbpasswd -s -a vagrant
# access share as "mount -t cifs  //server/homes /mnt -o username=vagrant"
# use "testparm -s" to view details of samba config on system "server"




;;
# end of server specfic code

*) echo "Hum, you should not see this message (check script $0 on system $(hostname))"
;;

esac
exit 0
