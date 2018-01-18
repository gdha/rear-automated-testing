# encoding: utf-8
# copyright: 2018, IT3 Consultants, Gratien D'haese
# license: All rights reserved

title 'sysctl'

control 'kernel.shmall' do
  title 'kernel.shmall check'
  desc "kernel.shmall was defined by ansible"
  impact 0.1

  describe kernel_parameter('kernel.shmall') do
    its('value') { should eq 2097152 }
  end
end

control 'kernel.shmmax' do
  title 'kernel.shmmax check'
  desc "kernel.shmmax was defined by ansible"
  impact 0.1

  describe kernel_parameter('kernel.shmmax') do
    its('value') { should eq 134217728 }
  end
end

control 'fs.file-max' do
  title 'fs.file-max check'
  desc "fs.file-max was defined by ansible"
  impact 0.1

  describe kernel_parameter('fs.file-max') do
    its('value') { should eq 65536 }
  end
end
