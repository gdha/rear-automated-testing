#!/bin/bash

echo "Provisioning centos/7"

# set up hostname (client) - is done via the Vagrantfile

# set up the timezone
#timedatectl set-timezone Europe/Brussels
# check the timezone:
#date


# do an update of the base system first
#echo "Running yum update..."
#yum update -y

# Define bareos and rear repo defintions
#wget -O /etc/yum.repos.d/bareos.repo http://download.bareos.org/bareos/release/latest/CentOS_7/bareos.repo
#wget -O /etc/yum.repos.d/Archiving:Backup:Rear:Snapshot.repo http://download.opensuse.org/repositories/Archiving:/Backup:/Rear:/Snapshot/CentOS_7/Archiving:Backup:Rear:Snapshot.repo
#wget -O /etc/yum.repos.d/home:gdha.repo http://download.opensuse.org/repositories/home:/gdha/CentOS_7/home:gdha.repo

#echo "Adding user vagrant and some security related stuff"
# Users, groups, passwords and sudoers.
#echo 'vagrant' | passwd --stdin root
#grep 'vagrant' /etc/passwd > /dev/null
#if [ $? -ne 0 ]; then
	#echo '* Creating user vagrant.'
	#useradd vagrant
	#echo 'vagrant' | passwd --stdin vagrant
#fi
#grep '^admin:' /etc/group > /dev/null || groupadd admin
#usermod -G admin vagrant

#echo 'Defaults    env_keep += "SSH_AUTH_SOCK"' >> /etc/sudoers
#echo '%admin ALL=NOPASSWD: ALL' >> /etc/sudoers
#sed -i 's/Defaults\s*requiretty/Defaults !requiretty/' /etc/sudoers


# SSH setup
# Add Vagrant ssh key for root and vagrant accouts.
# do not rely on DNS - we use /etc/hosts file for our Vagrant VMs:
#sed -i 's/.*UseDNS.*/UseDNS no/' /etc/ssh/sshd_config
# to allow a password prompt:
#sed -i 's/.*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
# To disbale errors like: man-in-the-middle attack with changed host keys (known_hosts):
#sed -i 's/.*StrictHostKeyChecking.*/StrictHostKeyChecking no/' /etc/ssh/sshd_config

# setup SSH keys for user root
#[ -d ~root/.ssh ] || mkdir  -m 700 ~root/.ssh
#cat >> ~root/.ssh/authorized_keys << EOF
#ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA6NF8iallvQVp22WDkTkyrtvp9eWW6A8YVr+kz4TjGYe7gHzIw+niNltGEFHzD8+v1I2YJ6oXevct1YeS0o9HZyN1Q9qgCgzUFtdOKLv6IedplqoPkcmF0aYet2PkEDo3MlTBckFXPITAMzF8dJSIFo9D8HfdOV0IAdx4O7PtixWKn5y2hMNG0zQPyUecp4pzC6kivAIhyfHilFR61RGL+GPXQ2MWZWFYbAGjyiYJnAmCP3NOTd0jMZEnDkbUvxhMmBYSdETk1rRgm+R4LOzFUGaHqHDLKLX+FIPKcF96hrucXzcWyLbIbEgE98OHlnVYCzRdK8jlqm8tehUc9c9WhQ== vagrant insecure public key
#EOF
#chmod 600 ~root/.ssh/authorized_keys
# use ssh-keygen to generate a new pair of SSH keys for root to exchange between client/server systems?
#echo "Generate a new keypair for root"
#ssh-keygen -t rsa -P '' -f ~root/.ssh/id_rsa

# setup SSH insecure key for user vagrant
#[ -d ~vagrant/.ssh ] || mkdir -m 700 ~vagrant/.ssh
#cat >> ~vagrant/.ssh/authorized_keys << EOF
#ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA6NF8iallvQVp22WDkTkyrtvp9eWW6A8YVr+kz4TjGYe7gHzIw+niNltGEFHzD8+v1I2YJ6oXevct1YeS0o9HZyN1Q9qgCgzUFtdOKLv6IedplqoPkcmF0aYet2PkEDo3MlTBckFXPITAMzF8dJSIFo9D8HfdOV0IAdx4O7PtixWKn5y2hMNG0zQPyUecp4pzC6kivAIhyfHilFR61RGL+GPXQ2MWZWFYbAGjyiYJnAmCP3NOTd0jMZEnDkbUvxhMmBYSdETk1rRgm+R4LOzFUGaHqHDLKLX+FIPKcF96hrucXzcWyLbIbEgE98OHlnVYCzRdK8jlqm8tehUc9c9WhQ== vagrant insecure public key
#EOF
#chmod 600 ~vagrant/.ssh/authorized_keys


# Disable firewall and switch SELinux to permissive mode.
#chkconfig iptables off
#chkconfig ip6tables off
# firewallD is by default not running with this box

# Networking setup..
#---------------------
# Fix slow DNS (issue #8):
# Add 'single-request-reopen' so it is included when /etc/resolv.conf is generated
# https://access.redhat.com/site/solutions/58625 (subscription required)
#echo 'RES_OPTIONS="single-request-reopen"' >>/etc/sysconfig/network
#service network restart
#echo 'Slow DNS fix applied (single-request-reopen)'

# Don't fix ethX names to hw address.
#rm -f /etc/udev/rules.d/*persistent-net.rules
#rm -f /etc/udev/rules.d/*-net.rules
#rm -fr /var/lib/dhclient/*

# SElinux settings when Enforce is on (default setting)
echo "Current mode of SELinux is \"$(getenforce)\"" 
echo "Disable SELinux for now"
setenforce 0
sed -i 's/^SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config

# add the domain name to the /etc/idmapd.conf file (for NFSv4)
sed -i -e 's,^#Domain =.*,Domain = box,' /etc/idmapd.conf

