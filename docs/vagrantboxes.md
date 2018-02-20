---
title: Vagrant Boxes
---

# Vagrant Boxes

Each Linux distribution you want to use for verifying Relax-and-Recover test cycle you first need to download the correspinding vagrant box. The `Vagrantfile` defines which vagrant box will be downloaded from [HashiCorp](https://app.vagrantup.com/boxes).

If for some reason you want to use another vagrant box than the one define in the `Vagrantfile` you need to modify the line:

    nodeconfig.vm.box =

A side note: use the **root** account to download the boxes as our project will require the root account anyhow.

To start the manual download (it is not mandatory, but strongly advised) go into the Linux distribution directory, e.g. `centos` and `sudo su` to become root.

To download the *Centos/7* box do the following:

    # vagrant box add  https://app.vagrantup.com/centos/boxes/7
    ==> box: Loading metadata for box 'https://app.vagrantup.com/centos/boxes/7'
    This box can work with multiple providers! The providers that it
    can work with are listed below. Please review the list and choose
    the provider you will be working with.
    
    1) hyperv
    2) libvirt
    3) virtualbox
    4) vmware_desktop
    
    Enter your choice: 3
    ==> box: Adding box 'centos/7' (v1801.02) for provider: virtualbox
        box: Downloading: https://vagrantcloud.com/centos/boxes/7/versions/1801.02/providers/virtualbox.box

You can list the available box on your system with the command `vagrant box list` 
