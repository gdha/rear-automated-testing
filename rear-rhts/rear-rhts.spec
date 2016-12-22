Name: rear-rhts
Summary: Automated software testing
Version: 4.71
Release: 1%{?dist}
Group: Development/Libraries
License: GPLv2+
Source0: http://fedorahosted.org/releases/r/h/%{name}-%{version}.tar.gz
Buildroot: %{_tmppath}/%{name}-%{version}-root
BuildArch: noarch

%description
This package is intended for people creating and maintaining tests, and
contains (or requires) the runtime components of the test system for 
installation on a workstation, along with development tools.

%package test-env
Summary: Testing API
Group: Development/Libraries
#Provides: rhts-testhelpers
#Provides: rhts-test-env-lab
#Provides: rhts-devel-test-env
#Provides: rhts-legacy
Requires: make

%description test-env
This package contains components of the test system used when running 
tests, either on a developer's workstation, or within a lab.

%prep
%setup -q


%build
[ "$RPM_BUILD_ROOT" != "/" ] && [ -d $RPM_BUILD_ROOT ] && rm -rf $RPM_BUILD_ROOT;

%install
DESTDIR=$RPM_BUILD_ROOT make -f Makefile.install install

# Legacy support.
#ln -s rhts-db-submit-result $RPM_BUILD_ROOT/usr/bin/rhts_db_submit_result
#ln -s rhts-environment.sh $RPM_BUILD_ROOT/usr/bin/rhts_environment.sh
#ln -s rhts-sync-set $RPM_BUILD_ROOT/usr/bin/rhts_sync_set
#ln -s rhts-sync-block $RPM_BUILD_ROOT/usr/bin/rhts_sync_block
#ln -s rhts-submit-log $RPM_BUILD_ROOT/usr/bin/rhts_submit_log
#mkdir -p $RPM_BUILD_ROOT/mnt/scratchspace
#mkdir -p $RPM_BUILD_ROOT/mnt/testarea

%clean
[ "$RPM_BUILD_ROOT" != "/" ] && [ -d $RPM_BUILD_ROOT ] && rm -rf $RPM_BUILD_ROOT;

%post
case "$1" in
  1) # This is an initial install.
     mkdir -p /mnt/scratchspace
     mkdir -p /mnt/testarea
     chmod -m 1777 /mnt/testarea
     if ! test -d /usr/share/rhts ; then
       ln -s /usr/share/%{name} /usr/share/rhts
     fi
     ;;
  2) # This is an upgrade.
     # Do nothing.
     :
     ;;
easc

%preun
case "$1" in
  0) # This is an un-installation.
     rm -rf /mnt/scratchspace
     rm -rf /mnt/testarea
     if test -h /usr/share/rhts ; then
       unlink /usr/share/rhts
     fi
     ;;
  1) # This is an upgrade.
     # Do nothing.
     :
     ;;
esac
     
%files test-env
%defattr(-,root,root)
%attr(0755, root, root)%{_bindir}/rhts-db-submit-result
%attr(0755, root, root)%{_bindir}/rhts-environment.sh
%attr(0755, root, root)%{_bindir}/rhts-run-simple-test
%attr(0755, root, root)%{_bindir}/rhts-report-result
%attr(0755, root, root)%{_bindir}/rhts-submit-log
%attr(0755, root, root)%{_bindir}/rhts-sync-block
%attr(0755, root, root)%{_bindir}/rhts-sync-set
%attr(0755, root, root)%{_bindir}/rhts-recipe-sync-block
%attr(0755, root, root)%{_bindir}/rhts-recipe-sync-set
%attr(0755, root, root)%{_bindir}/rhts-reboot
%attr(0755, root, root)%{_bindir}/rhts-backup
%attr(0755, root, root)%{_bindir}/rhts-restore
%attr(0755, root, root)%{_bindir}/rhts-system-info
%attr(0755, root, root)%{_bindir}/rhts-abort
%attr(0755, root, root)%{_bindir}/rhts-test-runner.sh
%attr(0755, root, root)%{_bindir}/rhts-test-checkin
%attr(0755, root, root)%{_bindir}/rhts-test-update
%attr(0755, root, root)%{_bindir}/rhts-extend
%attr(0755, root, root)%{_bindir}/rhts-power
%dir %{_datadir}/%{name}
%dir %{_datadir}/%{name}/lib
%attr(0644, root, root)%{_datadir}/%{name}/lib/rhts-make.include
%attr(0644, root, root)%{_datadir}/%{name}/failurestrings
%attr(0644, root, root)%{_datadir}/%{name}/falsestrings
#/mnt/scratchspace
#%attr(1777,root,root)/mnt/testarea
%doc doc/README

%changelog
* Mon Dec 12 2016 Gratien D'haese <gratien.dhaese@gmail.com> 4.71-2
- strip rths to work with rear integration testing
- renamed rhts to rear-rhts
* Thu Aug 04 2016 Dan Callaghan <dcallagh@redhat.com> 4.71-1
- populate task RPM's URL field with SCM URL (dcallagh@redhat.com)
- fix extra newlines in 'cut here' dmesg check output (dcallagh@redhat.com)
- falsestrings: match x3250 as well as X3250 (dcallagh@redhat.com)

