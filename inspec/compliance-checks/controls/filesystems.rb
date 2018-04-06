# encoding: utf-8
# copyright: 2018, IT3 Consultants, Gratien D'haese
# license: All rights reserved

title 'File systems'

control 'filesystem-root' do
  impact 1.0
  title 'Verify / directory'
  desc "The file system / is crucial for the Operating System"
  describe file('/') do
    it { should be_directory }
    #its('mode') { should cmp '00555' }
  end
end

control 'filesystem-tmp-exist' do
  impact 0.7
  title 'Verify /tmp directory'
  desc "The file system /tmp is crucial for the Operating System"
  describe file('/tmp') do
    it { should be_directory }
    its('mode') { should cmp '01777' }
  end
end

control 'filesystem-var-tmp-exist' do
  impact 0.7
  title 'Verify /var/tmp directory'
  desc "The file system /var/tmp is important for the Operating System"
  describe file('/var/tmp') do
    it { should be_directory }
    its('mode') { should cmp '01777' }
  end
end

control 'home-vagrant-exists' do
  impact 0.7
  title 'Verify /home/vagrant directory'
  desc "The home directory of the vagrant user should exist"
  describe file('/home/vagrant') do
    it { should be_directory }
  end
end
