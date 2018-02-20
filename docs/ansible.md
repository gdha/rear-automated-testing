---
title: Virtual Machine (VM) Provisioning with ansible
---

# Virtual Machine (VM) Provisioning with ansible

All the VM boxes are getting provisioned via ansible and the playbooks are centralized under the `centos7/ansible` directories. Also, the Ubuntu playbooks can be found under the centos7 directory. We use **blocks** to skip playbooks not meant for a particular Linxu distribution.

We tend to do the provisioning of the client and server VM before using the `rear-automated-test.sh`. Use the `--provision` option when you execute the `vagrant up`:

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
         
