#!/bin/bash

#######################################
if [ -f "/vagrant/.env" ]; then
  export $(grep -v '^#' /vagrant/.env | xargs -d '\n')
fi

NODE_TYPE=$1
NODE=$2

# Package versions
DOCKER_VERSION="19.03.8"
DOCKER_CE_PKG_VERSION="5:19.03.8~3-0~ubuntu-bionic"
DOCKER_CE_CLI_PKG_VERSION="5:19.03.8~3-0~ubuntu-bionic"
CONTAINERD_PKG_VERSION="1.2.13-1"

K8S_VERSION="1.18.3"
K8S_PKG_VERSION="${K8S_VERSION}-00"

# prevent warnning 'dpkg-preconfigure: unable to re-open stdin: No such file or directory'
export DEBIAN_FRONTEND=noninteractive 
#######################################

echo "######## Setting up ${NODE_TYPE} ${NODE} ########"

# Disable swap. Kubelet needs this to work properly.
echo "[TASK] Ensure swap is off"
swapoff -a

echo "[TASK] Remove swap from fstab"
sed -i '/swap/d' /etc/fstab

echo "[TASK] Ensure br_netfilter module is loaded"
modprobe br_netfilter

echo "[INFO] Check if br_netfilter is loaded"
lsmod | grep br_netfilter

# Add sysctl settings
echo "[TASK] Let iptables see bridged traffic"
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system >/dev/null 2>&1

# Update hosts file
echo "[TASK] Update /etc/hosts file"
if ! grep -q spkcluster /etc/hosts; then  
  sed -i '/spk/d' /etc/hosts

  echo "${SPK_KEEPALIVED_VIRTUAL_IP}    spkcluster    spkcluster.lab.local" >> /etc/hosts

  echo "172.42.42.11    spkmaster-1   spkmaster-1.lab.local" >> /etc/hosts
  echo "172.42.42.12    spkmaster-2   spkmaster-2.lab.local" >> /etc/hosts
  echo "172.42.42.13    spkmaster-3   spkmaster-3.lab.local" >> /etc/hosts

  echo "172.42.42.101   spkworker-1   spkworker-1.lab.local" >> /etc/hosts
  echo "172.42.42.102   spkworker-2   spkworker-2.lab.local" >> /etc/hosts
  echo "172.42.42.103   spkworker-3   spkworker-3.lab.local" >> /etc/hosts
  echo "172.42.42.104   spkworker-4   spkworker-4.lab.local" >> /etc/hosts
  echo "172.42.42.105   spkworker-5   spkworker-5.lab.local" >> /etc/hosts
  echo "172.42.42.106   spkworker-6   spkworker-6.lab.local" >> /etc/hosts
  echo "172.42.42.107   spkworker-7   spkworker-7.lab.local" >> /etc/hosts
  echo "172.42.42.108   spkworker-8   spkworker-8.lab.local" >> /etc/hosts
  echo "172.42.42.109   spkworker-9   spkworker-9.lab.local" >> /etc/hosts
fi

# /vagrant is the synced folder with the host.
echo "[Task] Ensure /vagrant/.kube exist"
mkdir -p /vagrant/.kube

# optional, for speeding up provisioning
echo "[TASK] Copy cached DEB packages if exists"
if [ -d /vagrant/.kube/apt-cache ]; then
  cp /vagrant/.kube/apt-cache/*.deb /var/cache/apt/archives
fi

echo "[TASK] Install packages to allow apt to use a repository over HTTPS"
apt-get update -y
apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg2

echo "[TASK] Add docker Apt key"
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1 apt-key add -

echo "[TASK] Add docker repository"
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

echo "[TASK] Add Google cloud Apt key"
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1 apt-key add -

# Add he kubernetes sources list into the sources.list directory
echo "[TASK] Ensure kubernetes repository"
cat <<EOF | tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

echo "[TASK] Update system"
apt-get update -y

echo "[TASK] List docker-ce versions"
apt-cache madison docker-ce > /vagrant/.kube/${HOSTNAME}-docker-ce-versions.txt

echo "[TASK] List containerd versions"
apt-cache madison containerd > /vagrant/.kube/${HOSTNAME}-containerd-versions.txt

echo "[TASK] List kubeadm versions"
apt-cache madison kubeadm > /vagrant/.kube/${HOSTNAME}-kubeadm-versions.txt

echo "[TASK] Install docker container engine v${DOCKER_VERSION}"
apt-get install -y containerd.io=${CONTAINERD_PKG_VERSION} \
  docker-ce-cli=${DOCKER_CE_PKG_VERSION} \
  docker-ce=${DOCKER_CE_CLI_PKG_VERSION}

echo "[TASK] Ensure User vagrant in Docker Group"
usermod -aG docker vagrant

# Setup daemon.
echo "[TASK] Setup /etc/docker/daemon.json"
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

mkdir -p /etc/systemd/system/docker.service.d

echo "[TASK] Restart docker"
systemctl daemon-reload
systemctl restart docker


# Install Kubernetes
echo "[TASK] Install Kubernetes kubeadm, kubelet and kubectl v${K8S_VERSION}"
apt-get install -y \
  kubelet=${K8S_PKG_VERSION} \
  kubeadm=${K8S_PKG_VERSION} \
  kubectl=${K8S_PKG_VERSION}

# these packages need special attention while upgrading
echo "[TASK] Exclude kubelet, kubeadm, kubectl from upgrade"
apt-mark hold kubelet kubeadm kubectl > /dev/null

echo "[TASK] Install open-iscsi package"
apt-get install -y open-iscsi > /dev/null

echo "[TASK] Enable and start iscsid"
systemctl enable iscsid
systemctl start iscsid

echo "[TASK] Update default user's bashrc file"
echo "export TERM=xterm" >> /etc/bashrc
