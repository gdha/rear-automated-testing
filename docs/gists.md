---
title: Uploading the test results to GitHub Gist
---

# Uploading the test results to GitHub Gist

## Software Requirements

Generate a personal authorisation code at GitHub - [https://github.com/settings/tokens](https://github.com/settings/tokens)

Copy the string into a file `~/.gist`

Note: be aware you cannot see the generated string anymore after you close the web page. Make sure, you copy/pasted it into a backup file somewhere.

Secondly, install the **gist** software - see code at GitHub - [https://github.com/defunkt/gist](https://github.com/defunkt/gist) and you probably need to install ruby if you miss it.

## Usage

That is the beauty of it it is so easy to use:

    $ ls -l /export/rear-tests/logs/2020-05-26_16-07-57
    total 156
    -rw-r--r--. 1 root root   2442 May 26 16:42 inspec_results_client_after_recovery
    -rw-r--r--. 1 root root   2442 May 26 16:10 inspec_results_client_before_recovery
    -rw-r--r--. 1 root root  10330 May 26 16:11 rear-automated-test.sh.log
    -rw-r--r--. 1 root root 105146 May 26 16:10 rear-client-mkbackup.log
    -rw-r--r--. 1 root root  28983 May 26 16:13 rear-client-recover.log


    $ gist /export/rear-tests/logs/2020-05-26_16-07-57/*
    https://gist.github.com/6d94e68d7548a915425b8ffd720dfed3

The URL returned is the location where you find those files back on the Internet. We typically use this URL on our [ReaR Wiki Test Matrix](https://github.com/rear/rear/wiki/Test-Matrix-rear-2.6) pages.
