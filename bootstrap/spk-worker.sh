#!/bin/bash

#######################################
NODE=$1

#######################################
echo "[TASK] Import docker images if exist"
# K8S
declare -a kube_images=(
  "kube-apiserver:v1.18.3.tar"
  "kube-proxy:v1.18.3.tar"
  "kube-controller-manager:v1.18.3.tar"
  "openebs-node-disk-manager:0.5.0.tar"
  "kube-scheduler:v1.18.3.tar"
  "pause:3.2.tar"
  "etcd:3.4.3-0.tar"
  "coredns:1.6.7.tar"
)

for img in "${kube_images[@]}"
do
  if [ -f /vagrant/.kube/docker-images/${img} ]; then
    docker load < /vagrant/.kube/docker-images/${img}
  fi
done

# Calico
declare -a calico_images=(
  "calico-node:v3.14.1.tar"
  "calico-pod2daemon-flexvol:v3.14.1.tar"
  "calico-kube-controllers:v3.14.1.tar"
  "calico-cni:v3.14.1.tar"
)

for img in "${calico_images[@]}"
do
  if [ -f /vagrant/.kube/docker-images/${img} ]; then
    docker load < /vagrant/.kube/docker-images/${img}
  fi
done

# OpenEBS images
declare -a openebs_images=(
  "openebs-m-exporter:1.10.0.tar"
  "openebs-m-apiserver:1.10.0.tar"
  "openebs-node-disk-manager:0.5.0.tar"
  "openebs-node-disk-operator:0.5.0.tar"
  "openebs-snapshot-controller:1.10.0.tar"
  "openebs-snapshot-provisioner:1.10.0.tar"
  "openebs-admission-server:1.10.0.tar"
  "openebs-cstor-istgt:1.10.0.tar"
  "openebs-cstor-volume-mgmt:1.10.0.tar"
  "openebs-cstor-pool-mgmt:1.10.0.tar"
  "openebs-cstor-pool:1.10.0.tar"
  "openebs-provisioner-localpv:1.10.0.tar"
  "openebs-k8s-provisioner:1.10.0.tar"
)

for img in "${openebs_images[@]}"
do
  if [ -f /vagrant/.kube/docker-images/${img} ]; then
    docker load < /vagrant/.kube/docker-images/${img}
  fi
done



# Join worker nodes to the Kubernetes cluster
echo "[TASK] Join worker ${NODE} to Kubernetes Cluster"
bash /vagrant/.kube/worker-join.sh | tee /root/kubejoin.log

echo "[TASK] Copy .kube config from /Vagrant"
mkdir -p /home/vagrant/.kube
cp /vagrant/.kube/config /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube
mkdir -p /root/.kube
cp /vagrant/.kube/config /root/.kube/config
