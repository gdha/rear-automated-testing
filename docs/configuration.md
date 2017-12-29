---
title: Configuration
---

# Configuration

There are no configuration requirements to use the Relax-and-Recover Automated Testing project. However, there is one exception for Bareos customers with a valid Bareos Subscription of Bareos Support Contract. These users have received a special login (and password) to download fixes and updates of the bareos software.

## Bareos Customers

For all users the public Bareos download area will be used, but if you wish to use the updated (subscribed) versions of bareos then you need to do the following additional steps *before* provisioning the *client* and *server* VMs with `vagrant`.

Enter the directory `rear-automated-testing/centos7/ansible/common/roles/rear-test/files` and copy the `bareos.ini.template` file into the same directory as `bareos.ini` (do **not** delete the `bareos.ini.template` file however!).

    $ cd rear-automated-testing/centos7/ansible/common/roles/rear-test/files
    $ cp bareos.ini.template bareos.ini
    $ vi bareos.ini

The `bareos.ini` file needs to be modified with your credentials you received from Bareos company.

    # Attention: for BAREOS customers who have a valid subscription or support contract may
    # copy this "bareos.ini.template" file to "bareos.ini" file and
    # modify the default attributes with your proper credentials which
    # allows you to download updated bareos packages
    #
    # bareos_user looks like "user%40example.com:" (in your mail address the @ is replaced by %40) (and always end with ":")
    # bareos_pass is "your_secret_password@" (provided by bareos) (and always append "@" to your password)
    # bareos_prot is "https://" (note s in https!)
    # bareos_fqdn is "download.bareos.com" (the "org" extention has been replaced by "com") 
    # bareos_path is "/bareos/release/" (do NOT change this line)
    # bareos_version is "latest" (you could change this to 16.2 or 17.2 or keep latest)
    # ATTENTION: do not use " around the values!
    [bareos]
    bareos_user =
    bareos_pass =
    bareos_prot = http://
    bareos_fqdn = download.bareos.org
    bareos_path = /bareos/release/
    bareos_version = latest

    For example, if your e-mail address is "user@company.com" and password "my-secret-pw" then modify the `bareos.ini` as follows:

    [bareos]
    bareos_user = user%40company.com:
    bareos_pass = my-secret-pw@
    bareos_prot = https://
    bareos_fqdn = download.bareos.com
    bareos_path = /bareos/release/
    bareos_version = latest

*Be aware* that the *bareos_user* key must end with an additional ":" and the *bareos_pass* should end with an additional "@". Furthermore, the *bareos_prot* should be modified to use the secure http protocol, and the *bareos_fqdn* address should have the "com" extension instead of the "org".
You are free to modify the *bareos_version* key to the value of the bareos version you want to install on the *client* and *server* VMs. However, make sure it is available on the location of bareos or the provisioning will fail.
