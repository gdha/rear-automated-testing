# encoding: utf-8
# copyright: 2018, IT3 Consultants, Gratien D'haese
# license: All rights reserved

title 'RPM integrity checks'

control 'iputils integrity' do
  title 'RPM integrity test on iputils package'
  desc "The ping executable requires cap_net_raw privilege. With rpm -V we can check the integrity of the package. ReaR recover sometimes do not restore the capabilities."

  if os.redhat?
    describe package('iputils') do
      it { should be_installed }
    end

    describe command("rpm -V iputils") do
      its(:stdout) { should eq '' }
    end
  end

end
