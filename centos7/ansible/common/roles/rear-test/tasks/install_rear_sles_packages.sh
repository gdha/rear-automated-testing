---
# ansible/common/roles/rear-test/tasks/install_rear_sles_packages.sh
# This section will only be executed with SLES distro's (currently equal with RHEL)
 
- name: Install packages required by ReaR
  package: name={{ item }} state=present
  with_items:
    - syslinux
    - cifs-utils
    - genisoimage
    - net-tools
    - samba
    - samba-client
    - mtools
    - sshfs
    - rear

