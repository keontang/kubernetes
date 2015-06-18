#!/bin/bash

# Copyright 2015 The Kubernetes Authors All rights reserved.
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


# Create etcd options used to start etcd on master.
#
# Input:
#   Instance name appearing to etcd. E.g. kubernetes-master, kubernetes-node0
#
function create-etcd-opts {
  cat <<EOF > ~/kube/default/etcd
ETCD_OPTS="-name $1 \
  -initial-advertise-peer-urls http://$2:2380 \
  -listen-peer-urls http://$2:2380 \
  -initial-cluster-token etcd-cluster-1 \
  -initial-cluster $3 \
  -initial-cluster-state new"
EOF
}

function create-kube-apiserver-opts {
  cat <<EOF > ~/kube/default/kube-apiserver
KUBE_APISERVER_OPTS="--address=0.0.0.0 \
--port=8080 \
--etcd_servers=http://127.0.0.1:4001 \
--logtostderr=true \
--service-cluster-ip-range=${1}"
EOF
}

function create-kube-controller-manager-opts {
  cat <<EOF > ~/kube/default/kube-controller-manager
KUBE_CONTROLLER_MANAGER_OPTS="--master=127.0.0.1:8080 \
--logtostderr=true"
EOF
}

function create-kube-scheduler-opts {
  cat <<EOF > ~/kube/default/kube-scheduler
KUBE_SCHEDULER_OPTS="--logtostderr=true \
--master=127.0.0.1:8080"
EOF
}

function create-kubelet-opts {
  cat <<EOF > ~/kube/default/kubelet
KUBELET_OPTS="--address=0.0.0.0 \
--port=10250 \
--hostname_override=$1 \
--api_servers=http://$2:8080 \
--logtostderr=true \
--cluster_dns=$3 \
--cluster_domain=$4 \
--pod-infra-container-image=$5"
EOF
}

function create-kube-proxy-opts {
  cat <<EOF > ~/kube/default/kube-proxy
KUBE_PROXY_OPTS="--master=http://${1}:8080 \
--logtostderr=true"
EOF
}

function create-flanneld-opts {
  cat <<EOF > ~/kube/default/flanneld
FLANNEL_OPTS="--iface=${1}"
EOF
}

# Input:
#   Interface name, e.g. eth1
#   Private address, e.g. 10.244.0.1
function create-private-interface-opts {
  cat <<-EOF > ~/kube/network/interfaces
	auto lo
	iface lo inet loopback
	auto ${1}
	iface ${1} inet static
	address ${2}
	netmask 255.255.0.0
EOF
}


# TODO: This can be slow in China's network, is there any better source?
function install-node {
  # Install docker on node
  sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 36A1D7869245C8950F966E92D8576A8BA88D21E9
  sudo sh -c "echo deb https://get.docker.io/ubuntu docker main > /etc/apt/sources.list.d/docker.list"
  sudo apt-get update
  sudo apt-get install -y --force-yes lxc-docker-1.6.2
  # Install brctl
  sudo apt-get install bridge-utils
}
