#
# Cookbook Name:: cerny_ceph
# Resource:: mds
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

resource_name 'ceph_mds'

property :name, String, name_property: true

load_current_value do

end

action :create do

end

action :start do

end

action :stop do

end

action :restart do

end

action :configure do

end

action :remove do

end
