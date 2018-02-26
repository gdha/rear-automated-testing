---
title: Virtual Machine (VM) Provisioning with ansible
---

# Virtual Machine (VM) Provisioning with ansible

All the VM boxes are getting provisioned via ansible and the playbooks are centralized under the `centos7/ansible` directory. Also, the Ubuntu playbooks can be found under the `centos7` directory. We use **blocks** to skip playbooks not meant for a particular Linxu distribution.

We tend to do the provisioning of the client and server VM before using the `rear-automated-test.sh` script. Use the `--provision` option when you execute the `vagrant up`:

    # vagrant up server --provision 
    ....
    ==> client: Rsyncing folder: /projects/rear/rear-automated-testing/centos7/ => /vagrant
    ==> client: Running provisioner: ansible_local...
        client: Installing Ansible...
        client: Running ansible-playbook...
    [DEPRECATION WARNING]: The sudo command line option has been deprecated in 
    favor of the "become" command line arguments. This feature will be removed in 
    version 2.6. Deprecation warnings can be disabled by setting 
    deprecation_warnings=False in ansible.cfg.
    
    PLAY [all] *********************************************************************
    
    TASK [Gathering Facts] *********************************************************
    ok: [client]
    
    TASK [rear-test : Install the hosts file] **************************************
    changed: [client]
    
    TASK [rear-test : include_tasks] ***********************************************
    included: /vagrant/ansible/common/roles/rear-test/tasks/bareos_ini_file.yml for client
    ....
         
Follow the same sequence for the *client* VM and once both VMs are fullu provisioned you are ready to use the `rear-automated-test.sh` script to test out ReaR.

In the `Vagrantfile` you probably saw that there is a third section about the *recover* VM, but nothing has to be done for that one as we will doing a bare metal restore via `rear -v recover` from rescue image made on the *client* VM.

## Ansible Common playbooks

The [`main.yml`](https://github.com/gdha/rear-automated-testing/blob/master/centos7/ansible/common/roles/rear-test/tasks/main.yml) playbook contains a list of tasks that will be executed on both the *client* and *server* VM via **ansible**
We use the *block* definition to separate the Debian from the RedHat families, threfore, all tasks run on both Ubuntu as CentOS VMs, but are skipped accordingly.

## Ansible Client playbooks

The [`main.yml`](https://github.com/gdha/rear-automated-testing/blob/master/centos7/ansible/client/roles/rear-test/tasks/main.yml) playbook will only run on the *client* VM. Roughly, it sets up a Bareos client and duplicity software among other smaller tasks.

## Ansible Server playbooks

The [`main.yml`](https://github.com/gdha/rear-automated-testing/blob/master/centos7/ansible/server/roles/rear-test/tasks/main.yml) playbook will only run on the *server* VM and will setup up a local DHCP server (including PXE), Bareos backup server, samba server and duplicity end-point server.

## New Playbooks or Tasks?

Of course, we are willing to add new playbooks or tasks if there is a request for it. Therefore, create an [issue](https://github.com/gdha/rear-automated-testing/issues) with your request. If it is a serious effort to implement the request then we expect we may raise a [purchase order](http://www.it3.be/rear-support/rear-support-pricelist.pdf) for it as we must invest time (and time is precious and expensive).

Of course, we welcome *Pull Requests* with new tasks or updates on existing tasks. We promise we will consider these seriously and give you feedback. Even minor corrections or enhacements are welcome, e.g. to fix grammar errors to name one (as I am not native English speaking).
