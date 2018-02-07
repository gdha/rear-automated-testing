---
title: Software Requirements
---

# Software Requirements

The software requirements on the host (hypervisor or whatever you call it) we need:

 - A hypervisor Linux system (or host system) to kick off Virtual Machines (VMs) via vagrant
 - vagrant (if possible install the version delivered by your distribution)
 - KVM with libvirt, or Oracle VirtualBox (required to start-up the Virtual Machines)
 - git (required to clone the software of this project)
 - nfs-server on the hypervosor (required to save the ISO images and/or logs)
 - tftp (might be needed by Oracle VirtualBox)
 - dos2unix (required by inspec to save output without control characters)
 - inspec (download from [Chef](https://downloads.chef.io/inspec))

## Download the sources of ReaR Automated testing

To clone the software just run the command:

    git clone https://github.com/gdha/rear-automated-testing.git


