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
# /export/nfs is used to store NFS backups
[[ ! -d /export/nfs ]] && mkdir -m 755 -p /export/nfs
# /export/archives is used to store sshfs or rsync backups
[[ ! -d /export/archives ]] && mkdir -m 755 -p /export/archives
[[ ! -d /export/nfs/tftpboot ]] && mkdir -m 755 -p /export/nfs/tftpboot

cat > /etc/exports <<EOF
/export/nfs 192.168.0.0/16(rw,no_root_squash)
EOF

# start the NFS service
systemctl start  nfs-idmapd rpcbind nfs-server
systemctl enable nfs-idmapd rpcbind nfs-server

echo "NFS exported file system on server:"
showmount -e

# install samba server + basic config
yum install -y samba samba-client 
systemctl start smb nmb 
systemctl enable smb nmb 
setsebool -P samba_enable_home_dirs on 
restorecon -R /home/vagrant
# adding user vagrant into smb passwd file with passwd vagrant
printf "vagrant\nvagrant\n" | smbpasswd -s -a vagrant
# access share as "mount -t cifs  //server/homes /mnt -o username=vagrant"
# use "testparm -s" to view details of samba config on system "server"

# install tftp-server and other pre-reqs
yum install -y tftp tftp-server xinetd
# after xinetd was installed we have our /etc/xinetd.d/tftp present
# now we need to modify it a bit
sed -i 's,.*/var/lib/tftpboot,\tserver_args\t\t= -s /export/nfs/tftpboot,' /etc/xinetd.d/tftp
sed -i 's,.*disable.*,\tdisable\t\t\t= no,' /etc/xinetd.d/tftp
systemctl start xinetd
systemctl enable xinetd

# install PXE booting pre-reqs
yum install -y dhcp syslinux-tftpboot
[[ ! -d /export/nfs/tftpboot/pxelinux.cfg ]] && mkdir -m 755 -p /export/nfs/tftpboot/pxelinux.cfg
cp /usr/share/syslinux/pxelinux.0 /export/nfs/tftpboot/
cp /usr/share/syslinux/menu.c32 /export/nfs/tftpboot/
chmod 644 /export/nfs/tftpboot/pxelinux.0

# configure /etc/dhcp/dhcpd.conf file for PXE booting
cat > /etc/dhcp/dhcpd.conf <<EOF
#
# DHCP Server Configuration file.
#   see /usr/share/doc/dhcp*/dhcpd.conf.example
#   see dhcpd.conf(5) man page
#

# specify domain name
option domain-name "box";
option domain-name-servers   192.168.33.15;
# default lease time
default-lease-time 600;
# max lease time
max-lease-time 7200;
# this DHCP server to be declared valid
authoritative; 

subnet 192.168.33.0 netmask 255.255.255.0 {
    # specify the range of lease IP address
    range dynamic-bootp 192.168.33.200 192.168.33.254;
    # specify broadcast address
    option broadcast-address 255.255.255.0;
    # specify default gateway
    option routers 192.168.33.1;
    # PXE boot file
    filename "pxelinux.0";
    # NFS/TFTP server 
    next-server 192.168.33.15;
}
EOF
systemctl restart dhcpd
systemctl enable dhcpd

;;
# end of server specfic code

*) echo "Hum, you should not see this message (check script $0 on system $(hostname))"
;;

esac
exit 0
