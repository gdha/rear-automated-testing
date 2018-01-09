# encoding: utf-8
# copyright: 2018, IT3 Consultants, Gratien D'haese
# license: All rights reserved

title 'File systems'

control 'filesystem-tmp-exist' do
  impact 0.7
  title 'Verify /tmp directory'
  desc "The file system /tmp is crucial for the Operating System"
  describe file('/tmp') do
    it { should be_directory }
  end
end
