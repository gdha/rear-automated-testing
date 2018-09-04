# encoding: utf-8
# copyright: 2018, IT3 Consultants, Gratien D'haese
# license: All rights reserved

title 'Basic Binaries Verification'

control 'basic_binaries' do
  title 'Basic binaries verification section'
  desc "Verify that after recovery the ownership and permissions stay the same"
  impact 1.0

  describe file('/bin/ls') do
    it { should be_file }
    its('mode') { should cmp '00755' }
    it { should be_owned_by 'root' }
    it { should be_grouped_into 'root' }
  end

  describe file('/usr/bin/ps') do
    it { should be_file }
    its('mode') { should cmp '00755' }
    it { should be_owned_by 'root' }
    it { should be_grouped_into 'root' }
  end

  describe file('/usr/bin/ping') do
    it { should be_file }
    its('mode') { should cmp '00755' }
    it { should be_owned_by 'root' }
    it { should be_grouped_into 'root' }
  end
end
