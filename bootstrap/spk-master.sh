#!/bin/bash

#######################################
if [ -f "/vagrant/.env" ]; then
  export $(grep -v '^#' /vagrant/.env | xargs -d '\n')
fi

NODE=$1
POD_CIDR=$2
API_ADV_ADDRESS=$3

K8S_VERSION="1.18.3"
CONTROL_PLANE_ENDPOINT="spkcluster.lab.local:16443"

HELM_VERSION="v3.2.1"

echo "[INFO] K8S_VERSION=${K8S_VERSION}"
echo "[INFO] POD_CIDR=${POD_CIDR}"
echo "[INFO] API_ADV_ADDRESS=${API_ADV_ADDRESS}"
echo "[INFO] CONTROL_PLANE_ENDPOINT=${CONTROL_PLANE_ENDPOINT}"
#######################################

main() {
  # setup HAProxy/Keepalive as HA API load balancer
  setup_control_plane_endpoint

  # preload docker images if exists, which are used for speeding up the provisioning.
  preload_docker_images

  if (( $NODE == 1 )) ; then
    # For first master node
    # Initialize Kubernetes cluster
    bootstrap_primary_master
  else
    # For other master nodes
    echo "[TASK] Join master ${NODE} to Kubernetes Cluster"
    bootstrap_secondary_master
  fi
}

setup_control_plane_endpoint() {
  echo "[TASK] Install HAProxy & keepalived"
  apt-get install -y haproxy keepalived

  echo "[TASK] Compose HAProxy config"
  write_haproxy_config

  echo "[TASK] Restart HAProxy daemon"
  systemctl restart haproxy

  echo "[TASK] Compose Keepalived config"
  write_keepalived_config

  echo "[TASK] Restart Keepalived daemon"
  systemctl restart keepalived
}

write_haproxy_config() {
  mkdir -p /etc/haproxy
  cat > /etc/haproxy/haproxy.cfg <<EOF
global
        log /dev/log    local0
        log /dev/log    local1 notice
        chroot /var/lib/haproxy
        stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
        stats timeout 30s
        user haproxy
        group haproxy
        daemon
        ca-base /etc/ssl/certs
        crt-base /etc/ssl/private
frontend spk-frontend
        bind *:16443
        mode tcp
        log global
        option tcplog
        timeout client 3600s
        backlog 4096
        maxconn 50000
        use_backend spk-masters
backend spk-masters
        mode  tcp
        option redispatch
        balance roundrobin
        timeout connect 1s
        timeout queue 5s
        timeout server 3600s
EOF

  echo "        server spkmaster-1 ${SPK_LAB_NETWORK}.11:6443 check" >> /etc/haproxy/haproxy.cfg
  echo "        server spkmaster-2 ${SPK_LAB_NETWORK}.12:6443 check" >> /etc/haproxy/haproxy.cfg
  echo "        server spkmaster-3 ${SPK_LAB_NETWORK}.13:6443 check" >> /etc/haproxy/haproxy.cfg
}


write_keepalived_config() {

cat <<EOF > /etc/keepalived/keepalived.conf
global_defs {
  default_interface ${SPK_KEEPALIVED_INTERFACE}
}
vrrp_instance VI_1 {
    interface ${SPK_KEEPALIVED_INTERFACE}
    virtual_router_id 101
    nopreempt
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    unicast_src_ip ${API_ADV_ADDRESS}
    unicast_peer {
      ${SPK_LAB_NETWORK}.11
      ${SPK_LAB_NETWORK}.12
      ${SPK_LAB_NETWORK}.13
    }
    virtual_ipaddress {
        ${SPK_KEEPALIVED_VIRTUAL_IP}
    }
}
EOF
}

preload_docker_images() {
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
}

bootstrap_primary_master() {

  echo "[TASK] Generate certificate key"
  CERTIFICATE_KEY=$(kubeadm alpha certs certificate-key)
  echo $CERTIFICATE_KEY > /vagrant/.kube/certificate-key

  echo "[TASK] Initialize Kubernetes Cluster"
  if [ "$SPK_VERBOSE" == "true" ]; then
    # '--v=5' for verbose output
    kubeadm init --apiserver-advertise-address=${API_ADV_ADDRESS} \
               --pod-network-cidr=${POD_CIDR} \
               --control-plane-endpoint=${CONTROL_PLANE_ENDPOINT} \
               --apiserver-cert-extra-sans spkcluster \
               --kubernetes-version=${K8S_VERSION} \
               --upload-certs \
               --v=5 \
               --certificate-key=${CERTIFICATE_KEY} | tee /root/kubeinit.log
  else
    kubeadm init --apiserver-advertise-address=${API_ADV_ADDRESS} \
               --pod-network-cidr=${POD_CIDR} \
               --control-plane-endpoint=${CONTROL_PLANE_ENDPOINT} \
               --apiserver-cert-extra-sans spkcluster \
               --kubernetes-version=${K8S_VERSION} \
               --upload-certs \
               --certificate-key=${CERTIFICATE_KEY} | tee /root/kubeinit.log
  fi


  # Copy Kube admin config
  echo "[TASK] Copy kube admin config to Vagrant user .kube directory"
  mkdir -p /home/vagrant/.kube
  cp /etc/kubernetes/admin.conf /home/vagrant/.kube/config
  chown -R vagrant:vagrant /home/vagrant/.kube
  mkdir -p /root/.kube
  cp /etc/kubernetes/admin.conf /root/.kube/config


  echo "[TASK] Copy config to /Vagrant for other VMs"
  mkdir -p /vagrant/.kube
  cp /etc/kubernetes/admin.conf /vagrant/.kube/config

  # Generate Cluster join command
  echo "[TASK] Generate and save worker join command to /vagrant/.kube/"
  kubeadm token create --print-join-command | tee /home/vagrant/worker-join.sh
  cat /home/vagrant/worker-join.sh | tr -d '\n' > /vagrant/.kube/worker-join.sh
  if [ "$SPK_VERBOSE" == "true" ]; then
    echo " --v=5" >> /vagrant/.kube/worker-join.sh
  else
    echo " " >> /vagrant/.kube/worker-join.sh
  fi

  echo "[TASK] Generate and save master join command to /vagrant/.kube/"
  kubeadm token create --certificate-key ${CERTIFICATE_KEY} --print-join-command > /home/vagrant/master-join.sh
  cat /home/vagrant/master-join.sh | tr -d '\n' > /vagrant/.kube/master-join.sh
  if [ "$SPK_VERBOSE" == "true" ]; then
    echo " --apiserver-advertise-address \${API_ADV_ADDRESS} --v=5" >> /vagrant/.kube/master-join.sh
  else
    echo " --apiserver-advertise-address \${API_ADV_ADDRESS}" >> /vagrant/.kube/master-join.sh
  fi
  
  # Deploy network plugin
  deploy_network_addon ${SPK_NETWORK_DRIVER}

  # Extra tools for first master node only
  install_common_tools
}

deploy_network_addon() {
  echo "[TASK] Deploy pod network add-on: $1"
  if [ "$1" == "cilium" ]; then
    kubectl create -f /vagrant/add-ons/cilium/
  elif [ "$1" == "calico" ]; then
    kubectl create -f /vagrant/add-ons/calico/
  else 
    echo "[WARN] No network add-on is specified."
  fi
}

install_common_tools() {
  echo "[TASK] Install common CLI tools"
  curl -sf https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz -o /tmp/helm-linux.tar.gz
  tar zxvf /tmp/helm-linux.tar.gz -C /tmp > /dev/null 2>&1
  mv /tmp/linux-amd64/helm /usr/local/bin
}

bootstrap_secondary_master() {
  #bash /vagrant/.kube/master-join.sh >/dev/null 2>&1
  API_ADV_ADDRESS=${API_ADV_ADDRESS} bash /vagrant/.kube/master-join.sh | tee /root/kubejoin.log

  echo "[TASK] Copy .kube config from /Vagrant"
  mkdir -p /home/vagrant/.kube
  cp /vagrant/.kube/config /home/vagrant/.kube/config
  chown -R vagrant:vagrant /home/vagrant/.kube
  mkdir -p /root/.kube
  cp /vagrant/.kube/config /root/.kube/config
}

main "$@"