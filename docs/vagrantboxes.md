---
title: Vagrant Boxes
---

# Vagrant Boxes

Each Linux distribution you want to use for verifying Relax-and-Recover test cycle you first need to download the corresponding vagrant box. The `Vagrantfile` defines which vagrant box will be downloaded from [HashiCorp](https://app.vagrantup.com/boxes).

If for some reason you want to use another vagrant box than the one define in the `Vagrantfile` you need to modify the line:

    nodeconfig.vm.box =

A side note: use the **root** account to download the boxes as our project will require the root account anyhow.

## Vagrant Box Add

To start the manual download (it is not mandatory, but strongly advised) go into the Linux distribution directory, e.g. `centos7` and `sudo su` to become root.

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

## Vagrant Box Update

It might be possible that during an *provisioning* or bringing up the boxes you will see a message that the Vagrant Box is out of date. You can bring the box up-to-date as following:

    # vagrant box update 
    ==> server: Checking for updates to 'centos/7'
        server: Latest installed version: 1801.02
        server: Version constraints: 
        server: Provider: virtualbox
    ==> server: Box 'centos/7' (v1801.02) is running the latest version.

In above case the box was already up-to-date and no further action was required.

## Vagrant Box List

To see which vagrant boxes are already present on your hosts system:

    # vagrant box list
    centos/7 (libvirt, 1702.01)
    centos/7 (libvirt, 1710.01)
    centos/7 (libvirt, 1801.02)

## Vagrant Box Remove

If you no longer require the use of one of the Vagrant Boxes you can simply:

- Remove the _client_ and _server_ virtual machines from your host system corresponding with the Vagrant Box
- Remove the Vagrant Box itself with the command `vagrant box remove`:


    # vagrant box remove centos/7 --box-version 1702.01
    Removing box 'centos/7' (v1702.01) with provider 'libvirt'...
    Vagrant-libvirt plugin removed box only from you LOCAL ~/.vagrant/boxes directory
    From libvirt storage pool you have to delete image manually(virsh, virt-manager or by any other tool)
    

As you can see from above output do not forget to clean up the _client_ and _server_ box in your preferred virtual manager tool (_virt-manager_ or _virtualbox_).
