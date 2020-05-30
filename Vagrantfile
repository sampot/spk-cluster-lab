# -*- mode: ruby -*-
# vi: set ft=ruby :


ENV['VAGRANT_NO_PARALLEL'] = 'yes'

Vagrant.configure(2) do |config|
  config.vagrant.plugins = ["vagrant-env"]
  config.vm.box_check_update = false

  if Vagrant.has_plugin?("vagrant-env")
    config.env.enable
  end
  
  ### base image
  BASE_BOX = ENV["SPK_BASE_BOX"] || "bento/ubuntu-18.04"
  BOX_VERSION = ENV["SPK_BOX_VERSION"] || "202003.31.0"

  ### network
  # only 3 components without trailing dot
  LAB_NETWORK = ENV["SPK_LAB_NETWORK"] || "172.42.42"

  # As per https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/
  # Cilium needs to use CIDR "10.217.0.0/16".
  POD_CIDR = ENV["SPK_CIDR"] || "10.217.0.0/16"

  ### master nodes
  MASTER_COUNT = (ENV["SPK_MASTER_COUNT"] || "1").to_i
  MASTER_MEMORY = (ENV["SPK_MASTER_MEMORY"] || "1024").to_i
  MASTER_CPUS = (ENV["SPK_MASTER_CPUS"] || "1").to_i

  ### worker nodes
  WORKER_COUNT = (ENV["SPK_WORKER_COUNT"] || "3").to_i
  WORKER_MEMORY = (ENV["SPK_WORKER_MEMORY"] || "2048").to_i
  WORKER_CPUS = (ENV["SPK_WORKER_CPUS"] || "2").to_i
  WORKER_EXTRA_DISK = ((ENV["SPK_WORKER_EXTRA_DISK"] || "false").downcase == 'true')
  WORKER_EXTRA_DISK_SIZE = (ENV["SPK_WORKER_EXTRA_DISK_SIZE"] || "10").to_i

  # Kubernetes Master Server
  (1..MASTER_COUNT).each do |i|
    config.vm.define "spkmaster-#{i}" do |masternode|
      masternode.vm.box = BASE_BOX
      masternode.vm.box_version = BOX_VERSION
      masternode.vm.hostname = "spkmaster-#{i}"
      # masternode.vm.synced_folder ".", "/vagrant"
      masternode.vm.network "private_network", ip: "#{LAB_NETWORK}.#{10+i}"
      # expose first master node's API endpoint
      masternode.vm.provider "virtualbox" do |v|
        v.name = "spkmaster-#{i}"
        v.memory = MASTER_MEMORY
        v.cpus = MASTER_CPUS
      end
      masternode.vm.provision "shell" do |s|
        s.inline = <<-SCRIPT
          bash /vagrant/bootstrap/spk-base.sh master #{i}
          bash /vagrant/bootstrap/spk-master.sh #{i} #{POD_CIDR} #{LAB_NETWORK}.#{10+i}
        SCRIPT
      end
    end
  end

  # Kubernetes Worker Nodes
  (1..WORKER_COUNT).each do |i|
    hostname = "spkworker-#{i}"
    config.vm.define "spkworker-#{i}" do |workernode|
      workernode.vm.box = BASE_BOX
      workernode.vm.box_version = BOX_VERSION
      workernode.vm.hostname = hostname
      workernode.vm.network "private_network", ip: "#{LAB_NETWORK}.#{100+i}"
      workernode.vm.provider "virtualbox" do |v|
        v.name = hostname
        v.memory = WORKER_MEMORY
        v.cpus = WORKER_CPUS

        if WORKER_EXTRA_DISK
          # attach an extra disk
          file_to_disk = "./.kube/#{hostname}-disk.vdi"
          unless File.exist?(file_to_disk)
            v.customize ['createhd', '--filename', file_to_disk, '--size', WORKER_EXTRA_DISK_SIZE * 1024]
          end
          v.customize ['storageattach', :id, '--storagectl', 'SATA Controller', '--port', 1, '--device', 0, '--type', 'hdd', '--medium', file_to_disk]
        end
      end
      workernode.vm.provision "shell" do |s|
        s.inline = <<-SCRIPT
          bash /vagrant/bootstrap/spk-base.sh worker #{i}
          bash /vagrant/bootstrap/spk-worker.sh #{i}
        SCRIPT
      end
    end
  end

end
