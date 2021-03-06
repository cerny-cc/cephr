#
# Cookbook Name:: cephr
# Resource:: mon
#
# Copyright 2016 Nathan Cerny
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# rubocop:disable LineLength

resource_name 'ceph_mon'

property :name, String, name_property: true
property :keyring, String

load_current_value do
  current_value_does_not_exist! unless exists?(name)
end

action :create do
  new_resource.keyring ||= "/var/lib/ceph/tmp/#{node.run_state['cephr']['cluster']}.mon.keyring"
  raise 'The Monitor keyring must be written before creating a monitor!' unless ::File.exist?(new_resource.keyring)

  directory "/var/lib/ceph/mon/ceph-#{new_resource.name}" do
    owner 'ceph'
    group 'ceph'
    mode '0750'
    recursive true
    action :create
  end

  directory '/var/lib/ceph/tmp/' do
    owner 'ceph'
    group 'ceph'
    mode '0750'
    recursive true
    action :create
  end

  package 'ceph-mon' do
    only_if 'yum search -C ceph-mon | grep ceph-mon'
  end

  package 'ceph' do
    not_if 'yum search -C ceph-mon | grep ceph-mon'
  end

  execute 'Add this monitor to monmap' do
    command "monmaptool --create --add #{new_resource.name} #{node.run_state['cephr']['monitors'][new_resource.name]} --fsid #{node.run_state['cephr']['config']['global']['fsid']} /var/lib/ceph/tmp/monmap"
    not_if { ::File.exist?("/var/lib/ceph/mon/ceph-#{new_resource.name}/done") }
  end

  # This is ugly.  State management is hard...this hack should work though.
  node.run_state['cephr']['monitors'].each do |host, ip|
    execute "Add monitor #{host} to monmap" do
      command "monmaptool --add #{host} #{ip} --fsid #{node.run_state['cephr']['config']['global']['fsid']} /var/lib/ceph/tmp/monmap"
      returns [0, 1]
      not_if { ::File.exist?("/var/lib/ceph/mon/ceph-#{new_resource.name}/done") }
    end
  end

  execute 'Populate Monitor Daemon' do
    command "ceph-mon --mkfs -i #{new_resource.name} --monmap /var/lib/ceph/tmp/monmap --keyring #{new_resource.keyring}"
    user 'ceph'
    not_if { ::File.exist?("/var/lib/ceph/mon/ceph-#{new_resource.name}/done") }
  end

  file "/var/lib/ceph/mon/ceph-#{new_resource.name}/done" do
    user 'ceph'
    action :create
  end

  service 'ceph.target' do
    supports restart: true, status: true
    action [:enable, :start]
  end if Chef::Platform::ServiceHelpers.service_resource_providers.include?(:systemd)

  service 'ceph-mon' do
    if Chef::Platform::ServiceHelpers.service_resource_providers.include?(:systemd)
      service_name "ceph-mon@#{new_resource.name}.service"
    elsif Chef::Platform::ServiceHelpers.service_resource_providers.include?(:upstart)
      service_name 'ceph-mon'
      parameters id: new_resource.name
    end
    supports restart: true, status: true
    action [:enable, :start]
  end
end

def exists?(mon)
  require 'timeout'
  begin
    Timeout.timeout(5) do
      Mixlib::ShellOut.new("ceph mon metadata #{mon}").run_command.error!
      true
    end
  rescue
    false
  end
end
