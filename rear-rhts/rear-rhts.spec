Name: rear-rhts
Summary: Automated software testing API
Version: 4.71
Release: 2%{?dist}
Group: Development/Libraries
License: GPLv2+
Source0: http://fedorahosted.org/releases/r/h/%{name}-%{version}.tar.gz
Buildroot: %{_tmppath}/%{name}-%{version}-root
BuildArch: noarch
Requires: make

%description
This package is intended for people creating and maintaining tests, and
contains (or requires) the runtime components of the test system for 
installation on a workstation, along with development tools.

%prep
%setup -q


%build
[ "$RPM_BUILD_ROOT" != "/" ] && [ -d $RPM_BUILD_ROOT ] && rm -rf $RPM_BUILD_ROOT;

%install
DESTDIR=$RPM_BUILD_ROOT make -f Makefile.install install

%clean
[ "$RPM_BUILD_ROOT" != "/" ] && [ -d $RPM_BUILD_ROOT ] && rm -rf $RPM_BUILD_ROOT;

%post
if [ $1 -eq 1 ] ; then
     mkdir -m 755 -p /mnt/scratchspace || :
     mkdir -m 1777 -p /mnt/testarea || :
     if ! test -d /usr/share/rhts ; then
       ln -s /usr/share/%{name} /usr/share/rhts || :
     fi
fi

%preun
if [ $1 -eq 0 ] ; then
     rm -rf /mnt/scratchspace || :
     rm -rf /mnt/testarea || :
     if test -h /usr/share/rhts ; then
       unlink /usr/share/rhts || :
     fi
fi

%files
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
%doc doc/README

%changelog
* Mon Dec 23 2016 Gratien D'haese <gratien.dhaese@gmail.com> 4.71-2
- strip rths to work with rear integration testing
- renamed rhts to rear-rhts
* Thu Aug 04 2016 Dan Callaghan <dcallagh@redhat.com> 4.71-1
- populate task RPM's URL field with SCM URL (dcallagh@redhat.com)
- fix extra newlines in 'cut here' dmesg check output (dcallagh@redhat.com)
- falsestrings: match x3250 as well as X3250 (dcallagh@redhat.com)

