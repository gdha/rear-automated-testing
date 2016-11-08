# rear-automated-testing
Relax-and-Recover (ReaR) Automated Testing is using Vagrant and standard GNU/Linux boxes to deploy one server and one client virtual machine (VM), and besides a recover VM is also created, but not proviosened. The main goal of this project is to foresee in a simple way to test the latest snapshot release of ReaR without too many manual interactions by doing a full backup with an automated restore into the *recover* VM.

In short we start the *client* and *server* VM via vagrant, and do a proviosining if required so that the *server* VM is capable of being a NFS server, PXE server and TFTP server. Then, we install the latest **ReaR** snapshot in the *client* VM and run a full backup using the *NETFS* backup method (with the help of `tar`). The tar archive is stored on the *server* VM and in the same time the PXE environment is configured on the *server* VM as well.
When the ReaR backup is completed we halt the *client* VM and start the *recover* VM and do a full restore of the *client* content. Once the restore is completed the *recover* VM reboot automatically.

## Clone this Git repository

`$ git clone https://github.com/gdha/rear-automated-testing.git`

## Execute the automated ReaR Recovery test

Select the GNU/Linux OS to test by going into the proper directory. However, initially we only have **centos7**, but more will follow over time (and do not forget it goes much faster with *sponsoring*).

````
$ cd rear-automated-testing/centos7/
$ vagrant up
````
