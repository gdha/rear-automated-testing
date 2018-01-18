# encoding: utf-8
# copyright: 2018, IT3 Consultants, Gratien D'haese
# license: All rights reserved

title 'Accounts'

control 'root-account' do
  title 'The super user account'
  desc "Make sure the root account exists."
  impact 1.0

  only_if do
    os.redhat? || os.debian? || os.linux? || os.darwin? || os.bsd?
  end
  describe user('root') do
    it { should exist }
  end
end

