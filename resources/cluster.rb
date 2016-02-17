#
# Cookbook Name:: cerny_ceph
# Resource:: cluster
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

require_relative '../libraries/helpers'
include CernyCeph::Helpers

resource_name 'ceph_cluster'

property :name, String, name_property: true
property :version, String, default: 'infernalis'
property :fsid, String
property :monitors, Hash, required: true
property :config, [String, Hash]

load_current_value do

end

action :install do
  node.run_state['ceph'] ||= {}
  node.run_state['ceph']['config'] ||= {}
  node.run_state['ceph']['config']['global'] ||= {}
  parse_config(config, 'global') unless config.nil?

  node.run_state['ceph']['cluster'] = new_resource.name
  node.run_state['ceph']['monitors'] = new_resource.monitors

  node.run_state['ceph']['config']['global']['fsid'] = new_resource.fsid if new_resource.fsid
  members = ''
  hosts = ''
  new_resource.monitors.each do |name, ip|
    members += ", #{name}"
    hosts += ", #{ip}"
  end
  node.run_state['ceph']['config']['global']['mon initial members'] = members.slice(2..-1)
  node.run_state['ceph']['config']['global']['mon host'] = hosts.slice(2..-1)

  fail 'fsid is required!' unless node.run_state['ceph']['config']['global']['fsid']

  case node['platform_family']
  when 'debian'
    include_recipe 'apt'

    apt_repository 'ceph' do
      uri "http://download.ceph.com/debian-#{new_resource.version}"
      components ['main']
      distribution node['lsb']['codename']
      key 'https://download.ceph.com/keys/release.asc'
      action :add
    end
  when 'rhel'
    include_recipe 'yum-epel'

    pv = node['platform_version'].split('.')[0]
    yum_repository 'ceph' do
      description 'Ceph packages for $basearch'
      baseurl "http://download.ceph.com/rpm-#{new_resource.version}/el#{pv}/$basearch"
      gpgkey 'https://download.ceph.com/keys/release.asc'
      action :create
    end
    yum_repository 'ceph-noarch' do
      description 'Ceph noarch packages'
      baseurl "http://download.ceph.com/rpm-#{new_resource.version}/el#{pv}/noarch"
      gpgkey 'https://download.ceph.com/keys/release.asc'
      action :create
    end
  end

  package 'ceph-common'
  package 'ceph'

  user 'ceph' do
    comment 'Ceph daemons'
    home '/var/lib/ceph'
    shell '/sbin/nologin'
  end

  directory '/etc/ceph' do
    owner 'ceph'
    group 'ceph'
    mode '0750'
    recursive true
    action :create
  end

  directory '/var/run/ceph' do
    owner 'ceph'
    group 'ceph'
    mode '0750'
    recursive true
    action :create
  end

  template "/etc/ceph/#{new_resource.name}.conf" do
    source 'ceph.conf.erb'
    cookbook 'cerny_ceph'
    owner 'ceph'
    group 'ceph'
    mode '0640'
  end
end

action :upgrade do

end