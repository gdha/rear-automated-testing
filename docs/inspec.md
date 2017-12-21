---
title: Compliance Checks using inspec
---

# Compliance Checks using inspec

We will be using the program `inspec` from Chef (freely available at [https://github.com/chef/inspec](https://github.com/chef/inspec)) to perform compliance checks on the client and the recovered system. Both should match.

## Installing inspec on the hypervisor

We do not need the `inspec` executable on our virtual machines, but we do need it to be available on our hypervisor (or the system from where you start up the vagrant VMs).
Go the the web-site [https://downloads.chef.io/inspec](https://downloads.chef.io/inspec) and dowload the appropriate package for your Linux distribution and install it on the hypervisor.

Check the basic functionality:

    $ sudo inspec detect
    
    == Operating System Details
    
    Name:      centos
    Family:    redhat
    Release:   7.3.1611
    Arch:      x86_64

Great it works. To test it out you can create a example test as follow:

    $ mkdir inspec ; cd inspec
    $ inspec init profile compliance-checks
    $ sudo inspec exec ../inspec/compliance-checks -i ../insecure_keys/vagrant.private -t ssh://root@client
    
    Profile: InSpec Profile (compliance-checks)
    Version: 0.1.0
    Target:  ssh://root@client:22
    
      ✔  tmp-1.0: Create /tmp directory
       ✔  File /tmp should be directory
    
      File /tmp
         ✔  should be directory
    
    Profile Summary: 1 successful control, 0 control failures, 0 controls skipped
    Test Summary: 2 successful, 0 failures, 0 skipped

As you can see from above example we can do a secure shell connection to the client VM and perform our little compliance test without requiring the executable to be present on the client VM itself.
