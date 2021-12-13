---
title: Uploading the test results to GitHub Gist
---

# Uploading the test results to GitHub Gist

## Software Requirements

Generate a personal authorisation code at GitHub - [https://github.com/settings/tokens](https://github.com/settings/tokens)

Copy the string into a file `~/.gist`

Note: be aware you cannot see the generated string anymore after you close the web page. Make sure, you copy/pasted it into a backup file somewhere.

Add the following code to your personal `~/.bash_profile`:

    GITHUB_TOKEN=$(cat $HOME/.gist)
    export GITHUB_TOKEN

Secondly, install the **gh cli** software - see code at GitHub - [GH cli README](https://github.com/cli/cli#installation)

## First time usage of gh cli

    gh auth login
    gh gist list

## Usage

That is the beauty of it it is so easy to use:

    $ ls -l /export/rear-tests/logs/2021-12-13_09-12-33
    total 156
    -rw-r--r--. 1 root root  2533 Dec 13 10:01 inspec_results_client_after_recovery
    -rw-r--r--. 1 root root  2442 Dec 13 09:18 inspec_results_client_before_recovery
    -rw-r--r--. 1 root root 10847 Dec 13 09:18 rear-automated-test.sh.log
    -rw-r--r--. 1 root root 75127 Dec 13 09:18 rear-client-mkbackup.log
    -rw-r--r--. 1 root root 25797 Dec 13 09:55 rear-client-recover.log


    $ cd /export/rear-tests/logs/2021-12-13_09-12-33
    gh gist create -p -d 'centos8 with bareos' *
    Creating gist with multiple files
    ✓ Created gist inspec_results_client_after_recovery
    https://gist.github.com/bf2fcb341e5842e30ca609ff9c7eca65

The URL returned is the location where you find those files back on the Internet. We typically use this URL on our [ReaR Wiki Test Matrix](https://github.com/rear/rear/wiki/Test-Matrix-rear-2.6) pages.
