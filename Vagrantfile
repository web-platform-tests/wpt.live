# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = '2'

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = 'debian/testing64'
  config.vm.network "private_network", ip: "172.30.1.5"

  config.vm.provision 'ansible' do |ansible|
    ansible.limit = "vagrant"
    ansible.inventory_path = "inventory/development"
    ansible.playbook = 'playbook.yml'
  end
end
