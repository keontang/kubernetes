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

#
# The script contains utilities used to create configs for kubernetes
# components. Configs are platform agnostic; however, it worths noting
# their behaviors:
#  1. Configs will be created under directory ~/kube/configs/.
#  2. Component config files will be put under /etc/kubernetes.
#  3. Binaries are put under /opt/bin.
#

# Create etcd options used to start etcd on master, see following documentation:
#   https://github.com/coreos/etcd/blob/master/Documentation/clustering.md
# Note since we have only one master right now, the options here do not contain
# clustering options, like initial-advertise-peer-urls, listen-peer-urls, etc.
#
# Input:
#   $1 Instance name appearing to etcd. E.g. kubernetes-master, etc.
#
# Output:
#   A file with etcd configs under ~/kube/configs/etcd.
function create-etcd-opts {
  cat <<EOF > ~/kube/configs/etcd
ETCD_OPTS="-name ${1} \
--listen-client-urls http://0.0.0.0:4001 \
--advertise-client-urls http://127.0.0.1:4001"
EOF
}

# Create apiserver options used to start kubernetes apiserver. The apiserver
# is configured to read certs, known tokens from "/etc/kubernetes" directory
# on master host.
#
# Input:
#   $1 Kubernetes cluster name.
#   $2 Service IP range. All kubernetes services fall into the range.
#   $3 Admmission control plugins enforced by apiserver.
#   $4 Cloudprovider name, leave empty if running without cloudprovider.
#   $5 Cloudprovider config file fullpath, e.g. /etc/kubernetes/caicloud-config,
#      leave empty if running without cloudprovider.
#
# Output:
#   A file with apiserver opts under ~/kube/configs/kube-apiserver.
#
# Assumed vars:
#   MASTER_INSECURE_ADDRESS
#   MASTER_INSECURE_PORT
#   MASTER_SECURE_ADDRESS
#   MASTER_SECURE_PORT
function create-kube-apiserver-opts {
  cat <<EOF | tr "\n" " " > ~/kube/configs/kube-apiserver
KUBE_APISERVER_OPTS="--logtostderr=true \
--insecure-bind-address=${MASTER_INSECURE_ADDRESS} \
--insecure-port=${MASTER_INSECURE_PORT} \
--bind-address=${MASTER_SECURE_ADDRESS} \
--secure-port=${MASTER_SECURE_PORT} \
--cors-allowed-origins=.* \
--etcd-servers=http://127.0.0.1:4001 \
--cluster-name=${1} \
--service-cluster-ip-range=${2} \
--admission-control=${3} \
--token-auth-file=/etc/kubernetes/known-tokens.csv \
--basic-auth-file=/etc/kubernetes/basic-auth.csv \
--client-ca-file=/etc/kubernetes/ca.crt \
--tls-cert-file=/etc/kubernetes/master.crt \
--tls-private-key-file=/etc/kubernetes/master.key
EOF
  if [[ "${4:-}" != "" ]]; then
    echo -n " --cloud-provider=${4}" >> ~/kube/configs/kube-apiserver
  fi
  if [[ "${5:-}" != "" ]]; then
    echo -n " --cloud-config=${5}" >> ~/kube/configs/kube-apiserver
  fi
  echo -n '"' >> ~/kube/configs/kube-apiserver
}

# Create controller manager options. Controller manager is configured to read
# private key, root ca from "/etc/kubernetes".
#
# Input:
#   $1 Kubernetes cluster name.
#   $2 Cloudprovider name, leave empty if running without cloudprovider.
#   $3 Cloudprovider config file fullpath, e.g. /etc/kubernetes/caicloud-config,
#      leave empty if running without cloudprovider.
#
# Output:
#   A file with controller manager configs under ~/kube/configs/kube-controller-manager.
#
# Assumed vars:
#   MASTER_INSECURE_ADDRESS
#   MASTER_INSECURE_PORT
function create-kube-controller-manager-opts {
  cat <<EOF | tr "\n" " " > ~/kube/configs/kube-controller-manager
KUBE_CONTROLLER_MANAGER_OPTS="--logtostderr=true \
--master=${MASTER_INSECURE_ADDRESS}:${MASTER_INSECURE_PORT} \
--cluster-name=${1} \
--service-account-private-key-file=/etc/kubernetes/master.key \
--root-ca-file=/etc/kubernetes/ca.crt
EOF
  if [[ "${2:-}" != "" ]]; then
    echo -n " --cloud-provider=${2}" >> ~/kube/configs/kube-controller-manager
  fi
  if [[ "${3:-}" != "" ]]; then
    echo -n " --cloud-config=${3}" >> ~/kube/configs/kube-controller-manager
  fi
  echo -n '"' >> ~/kube/configs/kube-controller-manager
}

# Create scheduler options.
#
# Output:
#   A file with scheduler configs under ~/kube/configs/kube-scheduler.
#
# Assumed vars:
#   MASTER_INSECURE_ADDRESS
#   MASTER_INSECURE_PORT
function create-kube-scheduler-opts {
  cat <<EOF | tr "\n" " " > ~/kube/configs/kube-scheduler
KUBE_SCHEDULER_OPTS="--logtostderr=true \
--master=${MASTER_INSECURE_ADDRESS}:${MASTER_INSECURE_PORT}"
EOF
}

# Create kubelet options, used to start kubelet on master or node.
#
# Input:
#   $1 The IP address for kubelet to serve on.
#   $2 Cluster DNS IP address, should fall into service IP range.
#   $3 Cluster search domain, e.g. cluster.local
#   $4 Pod infra image, i.e. the pause image. Default pause image comes from
#      gcr, which is sometimes blocked by GFW.
#   $5 Register the kubelet to master or not.
#   $6 Hostname override - override hostname used in kubelet, leave empty if
#      hostname override is unnecessary.
#   $7 API server address, typically master internal IP address, leave empty
#      if the kubelet instance runs on master.
#   $8 Cloudprovider name, leave empty if running without cloudprovider.
#   $9 Cloudprovider config file fullpath, e.g. /etc/kubernetes/anchnet-config,
#      leave empty if running without cloudprovider.
#
# Output:
#   A file with scheduler configs under ~/kube/configs/kubelet.
#
# Assumed vars:
#   MASTER_SECURE_PORT
#   KUBELET_PORT
function create-kubelet-opts {
  cat <<EOF | tr "\n" " " > ~/kube/configs/kubelet
KUBELET_OPTS="--logtostderr=true \
--address=${1} \
--cluster-dns=${2} \
--cluster-domain=${3} \
--pod-infra-container-image=${4} \
--register-node=${5} \
--port=${KUBELET_PORT} \
--system-container=/system \
--cgroup-root=/ \
--config=/etc/kubernetes/manifest \
--kubeconfig=/etc/kubernetes/kubelet-kubeconfig
EOF
  if [[ "${6:-}" != "" ]]; then
    local hostname=$(echo $6 | tr '[:upper:]' '[:lower:]') # lowercase input value
    echo -n " --hostname-override=${hostname} " >> ~/kube/configs/kubelet
  fi
  if [[ "${7:-}" != "" ]]; then
    echo -n " --api-servers=https://${7}:${MASTER_SECURE_PORT} " >> ~/kube/configs/kubelet
  fi
  if [[ "${8:-}" != "" ]]; then
    echo -n " --cloud-provider=${8} " >> ~/kube/configs/kubelet
  fi
  if [[ "${9:-}" != "" ]]; then
    echo -n " --cloud-config=${9} " >> ~/kube/configs/kubelet
  fi
  echo -n '"' >> ~/kube/configs/kubelet
}

# Create kube-proxy options, used to start proxy on master or node.
#
# Input:
#   $1 Whether running on "master" or "node.
#   $2 If running on node, this is the API server address, typically
#      master internal IP address.
#
# Output:
#   A file with scheduler configs under ~/kube/configs/kube-proxy.
#
# Assumed vars:
#   MASTER_INSECURE_ADDRESS
#   MASTER_INSECURE_PORT
#   MASTER_SECURE_PORT
function create-kube-proxy-opts {
  if [[ "${1:-}" == "master" ]]; then
    cat <<EOF > ~/kube/configs/kube-proxy
KUBE_PROXY_OPTS="--logtostderr=true \
--master=http://${MASTER_INSECURE_ADDRESS}:${MASTER_INSECURE_PORT} \
--kubeconfig=/etc/kubernetes/kube-proxy-kubeconfig"
EOF
  else
    cat <<EOF > ~/kube/configs/kube-proxy
KUBE_PROXY_OPTS="--logtostderr=true \
--master=https://${2}:${MASTER_SECURE_PORT}
--kubeconfig=/etc/kubernetes/kube-proxy-kubeconfig"
EOF
  fi
}

# Create flanneld options.
#
# Input:
#   $1 Interface or IP address used by flanneld to send internal traffic.
#   $2 etcd service endpoint IP address, used for flanneld to read configs.
#      For master, this is 127.0.0.1; for node, this is master internal IP
#      address.
function create-flanneld-opts {
  cat <<EOF > ~/kube/configs/flanneld
FLANNEL_OPTS="--iface=${1} --etcd-endpoints=http://${2}:4001"
EOF
}

# Config flanneld options in etcd. The method is called from master, and
# master should have etcdctl available.
#
# Input:
#   $1 Flannel overlay network CIDR
#   $2 Flannel subnet length
#   $3 Flannel subnet min
#   $4 Flannel subnet max
#   $5 Flannel type
function config-etcd-flanneld {
  attempt=0
  while true; do
    echo "Attempt $(($attempt+1)) to set flannel configuration in etcd"
    /opt/bin/etcdctl get "/coreos.com/network/config"
    if [[ "$?" == 0 ]]; then
      break
    else
      # Give a large timeout since this depends on status of etcd on
      # other machines.
      if (( attempt > 600 )); then
        echo "timeout waiting for network config"
        exit 2
      fi
      /opt/bin/etcdctl mk "/coreos.com/network/config" "{\"Network\":\"$1\", \"SubnetLen\":$2, \"SubnetMin\":\"$3\", \"SubnetMax\":\"$4\", \"Backend\": {\"Type\": \"$5\"}}"
      attempt=$((attempt+1))
      sleep 3
    fi
  done
}

# Configure docker network settings to use flannel overlay network.
#
# Input:
#   $1 Registry mirror address.
#   $2 File to write docker config, e.g. /etc/default/docker, /etc/sysconfig/docker.
function restart-docker {
  # Wait for /run/flannel/subnet.env to be ready.
  attempt=0
  while true; do
    echo "Attempt $(($attempt+1)) to check for subnet.env set by flannel"
    if [[ -f /run/flannel/subnet.env ]] && \
         grep -q "FLANNEL_SUBNET" /run/flannel/subnet.env && \
         grep -q "FLANNEL_MTU" /run/flannel/subnet.env ; then
      break
    else
      if (( attempt > 60 )); then
        echo "timeout waiting for subnet.env from flannel"
        exit 2
      fi
      attempt=$((attempt+1))
      sleep 3
    fi
  done

  # In order for docker to correctly use flannel setting, we first stop docker,
  # flush nat table, delete docker0 and then start docker. Missing any one of
  # the steps may result in wrong iptable rules, see:
  # https://github.com/caicloud/caicloud-kubernetes/issues/25
  sudo service docker stop
  sudo iptables -t nat -F
  sudo ip link set dev docker0 down
  sudo brctl delbr docker0

  source /run/flannel/subnet.env
  echo DOCKER_OPTS=\"-H tcp://127.0.0.1:4243 -H unix:///var/run/docker.sock \
       --bip=${FLANNEL_SUBNET} --mtu=${FLANNEL_MTU} --registry-mirror=$1 \
       --insecure-registry=get.caicloud.io\" > $2
  sudo service docker start
}
