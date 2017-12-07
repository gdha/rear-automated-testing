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

    $ ls -l /export/rear-tests/logs/2017-12-06_19-00-12/
    total 472
    -rw-r--r--. 1 root root   8500 Dec  6 19:07 rear-automated-test.sh.log
    -rw-r--r--. 1 root root 431081 Dec  6 19:01 rear-client-mkbackup.log
    -rw-r--r--. 1 root root  35882 Dec  6 19:03 rear-client-recover.log

    $ gist /export/rear-tests/logs/2017-12-06_19-00-12/*
    https://gist.github.com/eb9e17c5eed841452248a4fdd4d4343e

The URL returned is the location where you find the three files back on the Internet. I typically you that URL on our [ReaR Wiki Test Matrix](https://github.com/rear/rear/wiki/Test-Matrix-rear-2.3) pages.
