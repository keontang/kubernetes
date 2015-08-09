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

# Assumed vars (defined in config-default.sh):
#   MASTER_INSECURE_ADDRESS
#   MASTER_INSECURE_PORT
#   MASTER_SECURE_ADDRESS
#   MASTER_SECURE_PORT

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
--etcd_servers=http://127.0.0.1:4001 \
--service-cluster-ip-range=${1} \
--token_auth_file=/etc/kubernetes/known-tokens.csv \
--basic_auth_file=/etc/kubernetes/basic-auth.csv \
--client_ca_file=/etc/kubernetes/ca.crt \
--tls_cert_file=/etc/kubernetes/master.crt \
--tls_private_key_file=/etc/kubernetes/master.key \
--admission_control=${2} \
--cloud_config=/etc/kubernetes/anchnet-config \
--cloud_provider=anchnet"
EOF
}

# Create controller manager options.
function create-kube-controller-manager-opts {
  cat <<EOF > ~/kube/default/kube-controller-manager
KUBE_CONTROLLER_MANAGER_OPTS="--logtostderr=true \
--master=${MASTER_INSECURE_ADDRESS}:${MASTER_INSECURE_PORT} \
--cloud_config=/etc/kubernetes/anchnet-config \
--cloud_provider=anchnet \
--service-account-private-key-file=/etc/kubernetes/master.key \
--root-ca-file=/etc/kubernetes/ca.crt"
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
#   $1 Hostname override - override hostname used in kubelet.
#   $2 API server address, typically master internal IP address.
#   $3 Cluster DNS IP address, should fall into service ip range.
#   $4 Cluster search domain, e.g. cluster.local
#   $5 Pod infra image, i.e. the pause. Default pause image comes from gcr, which is
#      sometimes blocked by GFW.
function create-kubelet-opts {
  # Lowercase input value.
  local hostname=$(echo $1 | tr '[:upper:]' '[:lower:]')
  cat <<EOF > ~/kube/default/kubelet
KUBELET_OPTS="--logtostderr=true \
--address=0.0.0.0 \
--port=10250 \
--hostname_override=${hostname} \
--api_servers=https://${2}:${MASTER_SECURE_PORT} \
--cluster_dns=${3} \
--cluster_domain=${4} \
--pod-infra-container-image=${5} \
--kubeconfig=/etc/kubernetes/kubelet-kubeconfig \
--cloud_config=/etc/kubernetes/anchnet-config \
--cloud_provider=anchnet"
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

# Configure docker network settings to use flannel overlay network.
#
# Input:
#   $1 Flannel overlay network CIDR
#   $2 Registry mirror address
function config-docker-net {
  # Set flannel configuration to etcd.
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
      /opt/bin/etcdctl mk "/coreos.com/network/config" "{\"Network\":\"$1\"}"
      attempt=$((attempt+1))
      sleep 3
    fi
  done

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
       --bip=${FLANNEL_SUBNET} --mtu=${FLANNEL_MTU} --registry-mirror=$2\" > /etc/default/docker
  sudo service docker start
}

# Set hostname of an instance. In anchnet, hostname has the same format but
# different value than instance ID. We don't need the random hostname given
# by anchnet.
#
# Input:
#   $1 instance ID
function config-hostname {
  # Lowercase input value.
  local new_hostname=$(echo $1 | tr '[:upper:]' '[:lower:]')

  # Return early if hostname is already new.
  if [[ "`hostname`" == "${new_hostname}" ]]; then
    return
  fi

  if which hostnamectl > /dev/null; then
    hostnamectl set-hostname "${new_hostname}"
  else
    echo "${new_hostname}" > /etc/hostname
    hostname "${new_hostname}"
  fi

  if grep '127\.0\.1\.1' /etc/hosts > /dev/null; then
    sed -i "s/127\.0\.1\.1.*/127.0.1.1 ${new_hostname}/g" /etc/hosts
  else
    echo -e "127.0.1.1\t${new_hostname}" >> /etc/hosts
  fi

  echo "Hostname settings have been changed to ${new_hostname}."
}
