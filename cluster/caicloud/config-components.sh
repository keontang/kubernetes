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
# Output:
#   A file with etcd configs under ~/kube/configs/etcd.
function create-etcd-opts {
  cat <<EOF > ~/kube/configs/etcd
ETCD_OPTS="-name 'kubernetes-master' \
--listen-client-urls http://0.0.0.0:4001 \
--advertise-client-urls http://127.0.0.1:4001"
EOF
}

# Create apiserver options used to start kubernetes apiserver. The apiserver
# is configured to read certs, known tokens from "/etc/kubernetes" directory
# on master host.
#
# Output:
#   A file with apiserver opts under ~/kube/configs/kube-apiserver.
#
# Assumed vars:
#   ADMISSION_CONTROL
#   CAICLOUD_PROVIDER
#   CLUSTER_NAME
#   MASTER_INSECURE_ADDRESS
#   MASTER_INSECURE_PORT
#   MASTER_SECURE_PORT
#   SERVICE_CLUSTER_IP_RANGE
function create-kube-apiserver-opts {
  cat <<EOF | tr "\n" " " > ~/kube/configs/kube-apiserver
KUBE_APISERVER_OPTS="--logtostderr=true \
--insecure-bind-address=${MASTER_INSECURE_ADDRESS} \
--insecure-port=${MASTER_INSECURE_PORT} \
--bind-address=${MASTER_SECURE_ADDRESS} \
--secure-port=${MASTER_SECURE_PORT} \
--cors-allowed-origins=.* \
--etcd-servers=http://127.0.0.1:4001 \
--cluster-name=${CLUSTER_NAME} \
--service-cluster-ip-range=${SERVICE_CLUSTER_IP_RANGE} \
--admission-control=${ADMISSION_CONTROL} \
--token-auth-file=/etc/kubernetes/known-tokens.csv \
--basic-auth-file=/etc/kubernetes/basic-auth.csv \
--client-ca-file=/etc/kubernetes/ca.crt \
--tls-cert-file=/etc/kubernetes/master.crt \
--tls-private-key-file=/etc/kubernetes/master.key
EOF
  if [[ "${CAICLOUD_PROVIDER:-}" != "" ]]; then
    echo -n " --cloud-provider=${CAICLOUD_PROVIDER}" >> ~/kube/configs/kube-apiserver
    echo -n " --cloud-config=/etc/kubernetes/cloud-config" >> ~/kube/configs/kube-apiserver
  fi
  echo -n '"' >> ~/kube/configs/kube-apiserver
}

# Create controller manager options. Controller manager is configured to read
# private key, root CA from "/etc/kubernetes".
#
# Output:
#   A file with controller manager configs under ~/kube/configs/kube-controller-manager.
#
# Assumed vars:
#   CAICLOUD_PROVIDER
#   CLUSTER_NAME
#   MASTER_INSECURE_ADDRESS
#   MASTER_INSECURE_PORT
function create-kube-controller-manager-opts {
  cat <<EOF | tr "\n" " " > ~/kube/configs/kube-controller-manager
KUBE_CONTROLLER_MANAGER_OPTS="--logtostderr=true \
--master=${MASTER_INSECURE_ADDRESS}:${MASTER_INSECURE_PORT} \
--cluster-name=${CLUSTER_NAME} \
--service-account-private-key-file=/etc/kubernetes/master.key \
--root-ca-file=/etc/kubernetes/ca.crt
EOF
  if [[ "${CAICLOUD_PROVIDER:-}" != "" ]]; then
    echo -n " --cloud-provider=${CAICLOUD_PROVIDER}" >> ~/kube/configs/kube-controller-manager
    echo -n " --cloud-config=/etc/kubernetes/cloud-config" >> ~/kube/configs/kube-controller-manager
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
#   $1 Whether running on "master" or "node".
#   $2 Hostname override - override kubelet node hostname, leave empty if unnecessary.
#
# Output:
#   A file with scheduler configs under ~/kube/configs/kubelet.
#
# Assumed vars:
#   DNS_SERVER_IP
#   DNS_DOMAIN
#   MASTER_IIP
#   MASTER_SECURE_PORT
#   POD_INFRA_CONTAINER
#   KUBELET_IP_ADDRESS
#   KUBELET_PORT
#   REGISTER_MASTER_KUBELET
function create-kubelet-opts {
  cat <<EOF | tr "\n" " " > ~/kube/configs/kubelet
KUBELET_OPTS="--logtostderr=true \
--address=${KUBELET_IP_ADDRESS} \
--cluster-dns=${DNS_SERVER_IP} \
--cluster-domain=${DNS_DOMAIN} \
--pod-infra-container-image=${POD_INFRA_CONTAINER} \
--port=${KUBELET_PORT} \
--system-container=/system \
--cgroup-root=/ \
--config=/etc/kubernetes/manifest \
--kubeconfig=/etc/kubernetes/kubelet-kubeconfig
EOF
  # If this is master and we want to register master as a node, set --api-servers flag.
  # Register to node defaults to true if --api-servers is set.
  if [[ "${1:-}" == "master" && "${REGISTER_MASTER_KUBELET}" == "true" ]]; then
    echo -n " --api-servers=http://${MASTER_INSECURE_ADDRESS}:${MASTER_INSECURE_PORT} " >> ~/kube/configs/kubelet
  elif [[ "${1:-}" == "node" ]]; then
    echo -n " --api-servers=https://${MASTER_IIP}:${MASTER_SECURE_PORT} " >> ~/kube/configs/kubelet
  fi
  if [[ "${2:-}" != "" ]]; then
    local hostname=$(echo ${2} | tr '[:upper:]' '[:lower:]') # lowercase input value
    echo -n " --hostname-override=${hostname} " >> ~/kube/configs/kubelet
  fi
  if [[ "${CAICLOUD_PROVIDER:-}" != "" ]]; then
    echo -n " --cloud-provider=${CAICLOUD_PROVIDER} " >> ~/kube/configs/kubelet
    echo -n " --cloud-config=/etc/kubernetes/cloud-config " >> ~/kube/configs/kubelet
  fi
  echo -n '"' >> ~/kube/configs/kubelet
}

# Create kube-proxy options, used to start proxy on master or node.
#
# Input:
#   $1 Whether running on "master" or "node".
#
# Output:
#   A file with scheduler configs under ~/kube/configs/kube-proxy.
#
# Assumed vars:
#   MASTER_INSECURE_ADDRESS
#   MASTER_SECURE_PORT
#   MASTER_IIP
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
--master=https://${MASTER_IIP}:${MASTER_SECURE_PORT}
--kubeconfig=/etc/kubernetes/kube-proxy-kubeconfig"
EOF
  fi
}

# Create flanneld options.
#
# Input:
#   $1 Whether running on "master" or "node".
#
# Assumed vars:
#   MASTER_IIP
function create-flanneld-opts {
  # For master, etcd endpoint is 127.0.0.1; for node, it's master internal IP address.
  if [[ "${1:-}" == "master" ]]; then
    cat <<EOF > ~/kube/configs/flanneld
FLANNEL_OPTS="--iface=${FLANNEL_INTERFACE} --etcd-endpoints=http://127.0.0.1:4001"
EOF
  else
    cat <<EOF > ~/kube/configs/flanneld
FLANNEL_OPTS="--iface=${FLANNEL_INTERFACE} --etcd-endpoints=http://${MASTER_IIP}:4001"
EOF
  fi
}

# Config flanneld options in etcd. The method is called from master, and
# master should have etcdctl available.
#
# Assumed vars:
#   FLANNEL_NET
#   FLANNEL_SUBNET_LEN
#   FLANNEL_SUBNET_MIN
#   FLANNEL_SUBNET_MAX
#   FLANNEL_TYPE
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
      /opt/bin/etcdctl mk "/coreos.com/network/config" "{\"Network\":\"${FLANNEL_NET}\", \"SubnetLen\":${FLANNEL_SUBNET_LEN}, \"SubnetMin\":\"${FLANNEL_SUBNET_MIN}\", \"SubnetMax\":\"${FLANNEL_SUBNET_MAX}\", \"Backend\": {\"Type\": \"$FLANNEL_TYPE\"}}"
      attempt=$((attempt+1))
      sleep 3
    fi
  done
}

# Configure docker network settings to use flannel overlay network.
#
# Input:
#   $1 File to write docker config, e.g. /etc/default/docker, /etc/sysconfig/docker.
#
# Assumed vars:
#   REGISTRY_MIRROR
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
       --bip=${FLANNEL_SUBNET} --mtu=${FLANNEL_MTU} \
       --registry-mirror=${REGISTRY_MIRROR} \" > ${1}
  sudo service docker start
}
