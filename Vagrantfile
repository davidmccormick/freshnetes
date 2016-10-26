# -*- mode: ruby -*-
# vi: set ft=ruby :

ENV['VAGRANT_DEFAULT_PROVIDER']='virtualbox'
Vagrant.configure(2) do |config|
config.ssh.insert_key = false
#config.vm.provider :virtualbox do |v|
#  v.check_guest_additions = false
##  v.functional_vboxsf     = false
#end
config.vm.synced_folder ".", "/vagrant", disabled: true
  config.vm.box = "centos/7"

  config.vm.define :master do |master01_config|
      master01_config.vm.network "private_network", ip:"10.250.250.2"
      # Can't use 192.168.100.1 - this is probably assigned to vagrant host as gw
      master01_config.vm.guest = :atomic
      master01_config.vm.hostname = "master.example.com"
      #master01_config.vm.provider :libvirt do |libv|
      #	libv.memory=512
      #	libv.cpus=1
      #end
      config.vm.provider :virtualbox do |vb|
        vb.customize ["modifyvm", :id, "--memory", "512"]
        vb.customize ["modifyvm", :id, "--cpus", "1"]   
      end  
      master01_config.vm.provision :file, source: "kubernetes/server/kubernetes/server/bin/hyperkube", destination: "hyperkube"
      master01_config.vm.provision :file, source: "kubeadm", destination: "kubeadm"
      master01_config.vm.provision :file, source: "kubernetes/server/kubernetes-manifests.tar.gz", destination: "kubernetes-manifests.tar.gz"
      master01_config.vm.provision :file, source: "flannel-linux-amd64.tar.gz", destination: "flannel-linux-amd64.tar.gz"
      master01_config.vm.provision :file, source: "etcd-linux-amd64.tar.gz", destination: "etcd-linux-amd64.tar.gz"
      master01_config.vm.provision :shell, path: "shared.sh", :privileged => true
      master01_config.vm.provision :shell, path: "master.sh", :privileged => true
      #master01_config.vm.provision :shell, path: "addons.sh", :privileged => true
  end

  config.vm.define :minion01 do |minion01_config|
      minion01_config.vm.network "private_network", ip:"10.250.250.10"
      minion01_config.vm.guest = :atomic
      minion01_config.vm.hostname = "minion01.example.com"
      #minion01_config.vm.provider :libvirt do |libv|
	#libv.memory=512
	#libv.cpus=1
      #end
      config.vm.provider :virtualbox do |vb|
        vb.customize ["modifyvm", :id, "--memory", "1024"]
        vb.customize ["modifyvm", :id, "--cpus", "2"]   
      end  
      minion01_config.vm.provision :file, source: "kubernetes/server/kubernetes/server/bin/hyperkube", destination: "hyperkube"
      minion01_config.vm.provision :shell, path: "shared.sh", :privileged => true
      minion01_config.vm.provision :file, source: "kubeadm", destination: "kubeadm"
      #minion01_config.vm.provision :shell, path: "minion.sh", :privileged => true
  end

#  config.vm.define :minion02 do |minion02_config|
#      minion02_config.vm.network "private_network", ip:"10.250.250.11"
#      minion02_config.vm.guest = :atomic
#      minion02_config.vm.hostname = "minion02.example.com"
#      #minion01_config.vm.provider :libvirt do |libv|
#	#libv.memory=512
#	#libv.cpus=1
#      #end
#      config.vm.provider :virtualbox do |vb|
#        vb.customize ["modifyvm", :id, "--memory", "1024"]
#        vb.customize ["modifyvm", :id, "--cpus", "2"]   
#      end  
#      minion02_config.vm.provision :shell, path: "shared.sh", :privileged => true
#      #minion02_config.vm.provision :shell, path: "minion.sh", :privileged => true
#  end
end
