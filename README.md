# Local Lab for Simple Portable K8S Cluster

A Kubernetes playground for experimenting cloud-native DevOps practices.

## Prerequisites

Following tools are used for automating environment setup:

- Vagrant 2.2.9
- VirtualBox 6.0.20

The project uses vargrant-env plugin, use following instruction to install it if not done yet:

```sh
vagrant plugin install vagrant-env
```

The setup is currently tested on OS X Catalina only.

## Setup

The repo contains scripts for setting up a K8S cluster with varisous number of master and worker nodes. Each worker node has an extra disk which is needed for some storage plugins such as [OpenEBS](https://openebs.io/), [ROOK](https://rook.io/), etc.

In the setup, as master node is not used for scheduling, there are 3 worker nodes by default. The rationale is that some packages(e.g. etcd) need 3 replicas for minimal quorum to support high availability.

## Get Started

Given that Vagrant and VirtualBox are already installed on host, follow instructions below to launch the cluster:

```sh
git clone https://github.com/sampot/spk-cluster-lab.git
cd spk-cluster-lab
cp .env.example .env
vagrant up
```

It's time-consuming to build the cluster from scratch, save snapshots that can be latter restored if needed. Use following command to create a snapshot named `baseline`:

```sh
vagrant snapshot save baseline
```

With the snapshot saved, you may experiment setting up various K8S packages. Whenever you've done experimenting and want to go back to a previous clean state, use following command to do just that:

```sh
vagrant snapshot restore baseline
```
`baseline` is just a snapshot name, you may save any number of snapshots of different configurations so that you may conveniently recover the very configuration anytime.

## Credits

The repos is based on or inspired by following projects:

- [k8s_ubuntu](https://bitbucket.org/exxsyseng/k8s_ubuntu/src/master/)
- [Bootstraping clusters with kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
- [How to build a full kubernetes cluster in your home lab using an automated, easy and fancy way!](https://medium.com/kuberverse/how-to-build-a-full-kubernetes-cluster-in-your-home-lab-using-an-automated-easy-and-fancy-way-e5853ae4e08)
