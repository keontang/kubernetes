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


# MASTER_INSECURE_* is used to server insecure connection. It is either
# localhost, blocked by firewall, or use with nginx, etc. MASTER_SECURE_*
# is accessed directly from outside world, serving HTTPS. Thses configs
# should rarely change.
MASTER_INSECURE_ADDRESS="127.0.0.1"
MASTER_INSECURE_PORT=8080
MASTER_SECURE_ADDRESS="0.0.0.0"
MASTER_SECURE_PORT=6443


# Create etcd options used to start etcd on master/nodes.
# https://github.com/coreos/etcd/blob/master/Documentation/clustering.md
#
# Input:
#   $1 Instance name appearing to etcd. E.g. kubernetes-master, kubernetes-node0, etc.
#   $2 IP address used to listen to peer connection, typically instance internal address.
#   $3 Static cluster configuration setup.
function create-etcd-opts {
  cat <<EOF > ~/kube/default/etcd
ETCD_OPTS="-name ${1} \
-initial-advertise-peer-urls http://${2}:2380 \
-listen-peer-urls http://${2}:2380 \
-initial-cluster-token etcd-cluster-1 \
-initial-cluster ${3} \
-initial-cluster-state new"
EOF
}

# Create apiserver options.
#
# Input:
#   $1 Service IP range. All kubernetes service will fall into the range.
function create-kube-apiserver-opts {
  cat <<EOF > ~/kube/default/kube-apiserver
KUBE_APISERVER_OPTS="--logtostderr=true \
--insecure-bind-address=${MASTER_INSECURE_ADDRESS} \
--insecure-port=${MASTER_INSECURE_PORT} \
--bind-address=${MASTER_SECURE_ADDRESS} \
--secure-port=${MASTER_SECURE_PORT} \
--token_auth_file=/etc/kubernetes/known-tokens.csv \
--etcd_servers=http://${MASTER_INSECURE_ADDRESS}:4001 \
--service-cluster-ip-range=${1}"
EOF
}

# Create controller manager options.
function create-kube-controller-manager-opts {
  cat <<EOF > ~/kube/default/kube-controller-manager
KUBE_CONTROLLER_MANAGER_OPTS="--logtostderr=true \
--master=${MASTER_INSECURE_ADDRESS}:${MASTER_INSECURE_PORT}"
EOF
}

# Create scheduler options.
function create-kube-scheduler-opts {
  cat <<EOF > ~/kube/default/kube-scheduler
KUBE_SCHEDULER_OPTS="--logtostderr=true \
--master=${MASTER_INSECURE_ADDRESS}:${MASTER_INSECURE_PORT}"
EOF
}

# Create kubelet options.
#
# Input:
#   $1 Hostname override. Before cloudprovide interface is implemented, we use this
#      to override hostname of the instance.
#   $2 API server address, typically master internal IP address.
#   $3 Cluster DNS IP address, should fall into service ip range.
#   $4 Cluster search domain, e.g. cluster.local
#   $5 Pod infra image, i.e. the pause. Default pause image comes from gcr, which is
#      sometimes blocked by GFW.
function create-kubelet-opts {
  cat <<EOF > ~/kube/default/kubelet
KUBELET_OPTS="--logtostderr=true \
--address=0.0.0.0 \
--port=10250 \
--hostname_override=${1} \
--api_servers=https://${2}:${MASTER_SECURE_PORT} \
--cluster_dns=${3} \
--cluster_domain=${4} \
--pod-infra-container-image=${5} \
--kubeconfig=/etc/kubernetes/kubelet-kubeconfig"
EOF
}

# Create kube-proxy options
#
# Input:
#   $1 API server address, typically master internal IP address
function create-kube-proxy-opts {
  cat <<EOF > ~/kube/default/kube-proxy
KUBE_PROXY_OPTS="--logtostderr=true \
--master=https://${1}:${MASTER_SECURE_PORT} \
--kubeconfig=/etc/kubernetes/kube-proxy-kubeconfig"
EOF
}

# Create flanneld options.
#
# Input:
#   $1 Interface used by flanneld to send internal traffic. Because we use anchnet
#      private SDN network, this should be set to the instance's SDN private IP.
function create-flanneld-opts {
  cat <<EOF > ~/kube/default/flanneld
FLANNEL_OPTS="--iface=${1}"
EOF
}

# Create private interface opts, used by network manager to bring up private SDN
# network interface.
#
# Input:
#   $1 Interface name, e.g. eth1
#   $2 Static private address, e.g. 10.244.0.1
#   $3 Private address master, e.g. 255.255.0.0
function create-private-interface-opts {
  cat <<EOF > ~/kube/network/interfaces
	auto lo
	iface lo inet loopback
	auto ${1}
	iface ${1} inet static
	address ${2}
	netmask ${3}
EOF
}
