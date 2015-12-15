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

# -----------------------------------------------------------------------------
# Params from executor for kube-up.
# -----------------------------------------------------------------------------
# Linux distribution of underline machines.
KUBE_DISTRO=${KUBE_DISTRO:-"trusty"}

# ssh information for master.
MASTER_SSH_INFO="vagrant:vagrant@192.168.205.10"

# ssh information for nodes (comma separated string).
NODE_SSH_INFO="vagrant:vagrant@192.168.205.11"

# Name of the cluster. This is used for constructing the prefix of resource IDs
# in anchnet. The same name needs to be specified when running kube-down to
# release the resources acquired during kube-up.
CLUSTER_NAME=${CLUSTER_NAME:-"kube-default"}

# The version of caicloud release to use if building release is not required.
# E.g. v1.0.2, 2015-09-09-15-30-30, etc.
CAICLOUD_KUBE_VERSION=${CAICLOUD_KUBE_VERSION:-"v0.5.0"}

# KUBE_USER uniquely identifies a caicloud user. This is the user that owns the
# cluster, and will be used to create kubeconfig file.
KUBE_USER=${KUBE_USER:-""}

# Directory for holding kubeup instance specific logs. During kube-up, instances
# will be installed/provisioned concurrently; if we just send logs to stdout,
# stdout will mess up. Therefore, we specify a directory to hold instance specific
# logs. All other logs will be sent to stdout, e.g. create instances from anchnet.
KUBE_INSTANCE_LOGDIR=${KUBE_INSTANCE_LOGDIR:-"/tmp/kubeup-`TZ=Asia/Shanghai date +%Y-%m-%d-%H-%M-%S`"}

# URL path of the server hosting caicloud kubernetes release.
CAICLOUD_HOST_URL=${CAICLOUD_HOST_URL:-"http://7xli2p.dl1.z0.glb.clouddn.com"}

# Docker version. Ideally, this should come with CAICLOUD_KUBE_VERSION, but
# there is no easy to enforce docker version in caicloud kubernetes release,
# so we define it here separately.
DOCKER_VERSION=${DOCKER_VERSION:-"1.8.3"}

# To indicate if the execution status needs to be reported back to caicloud
# executor via curl. Set it to be Y if reporting is needed.
REPORT_KUBE_STATUS=${REPORT_KUBE_STATUS:-"N"}

# Anchnet config file to use. All user clusters will be created under one
# anchnet account (register@caicloud.io) using sub-account, so this file
# rarely changes.
ANCHNET_CONFIG_FILE=${ANCHNET_CONFIG_FILE:-"$HOME/.anchnet/config"}

# Daocloud registry accelerator. Before implementing our own registry (or registry
# mirror), use this accelerator to make pulling image faster. The variable is a
# comma separated list of mirror address, we randomly choose one of them.
#   http://47178212.m.daocloud.io -> deyuan.deng@gmail.com
#   http://dd69bd44.m.daocloud.io -> 729581241@qq.com
#   http://9482cd22.m.daocloud.io -> dalvikbogus@gmail.com
#   http://4a682d3b.m.daocloud.io -> 492886102@qq.com
DAOCLOUD_ACCELERATORS=${DAOCLOUD_ACCELERATORS:-"\
http://47178212.m.daocloud.io,http://dd69bd44.m.daocloud.io,\
http://9482cd22.m.daocloud.io,http://4a682d3b.m.daocloud.io"}

# Ubuntu/Debian apt mirrors. In case of installation errors from any of the mirrors,
# we switch to a backup.
APT_MIRRORS="http://mirrors.163.com/ubuntu/,http://ftp.sjtu.edu.cn/ubuntu/"

# -----------------------------------------------------------------------------
# Parameter from executor for cluster addons.
# -----------------------------------------------------------------------------
# Optional: Install cluster DNS.
ENABLE_CLUSTER_DNS=${ENABLE_CLUSTER_DNS:-true}
DNS_SERVER_IP=${DNS_SERVER_IP:-10.254.0.100} # Must be a IP in SERVICE_CLUSTER_IP_RANGE.
DNS_DOMAIN=${DNS_DOMAIN:-"cluster.local"}
DNS_REPLICAS=${DNS_REPLICAS:-1}

# Optional: When set to true, fluentd, elasticsearch and kibana will be setup as part
# of the cluster bring up.
ENABLE_CLUSTER_LOGGING=${ENABLE_CLUSTER_LOGGING:-true}
ELASTICSEARCH_REPLICAS=${ELASTICSEARCH_REPLICAS:-2}
KIBANA_REPLICAS=${KIBANA_REPLICAS:-1}

# Optional: Install Kubernetes UI.
ENABLE_CLUSTER_UI=${ENABLE_CLUSTER_UI:-true}
KUBE_UI_REPLICAS=${KUBE_UI_REPLICAS:-1}

# Optional: Install cluster registry.
ENABLE_CLUSTER_REGISTRY=${ENABLE_CLUSTER_REGISTRY:-true}

# Optional: Install cluster monitoring. Disable by default, under developing.
ENABLE_CLUSTER_MONITORING=${ENABLE_CLUSTER_MONITORING:-false}
# TODO: config the default memory limit according to num of nodes.
HEAPSTER_MEMORY=${HEAPSTER_MEMORY:-"300Mi"}


# -----------------------------------------------------------------------------
# Cluster IP address and ranges: all are static configuration values.
# -----------------------------------------------------------------------------
# Define the IP range used for service cluster IPs. If this is ever changed,
# fixed cluster service IP needs to be changed as well, including DNS_SERVER_IP.
SERVICE_CLUSTER_IP_RANGE=10.254.0.0/16  # formerly PORTAL_NET

# Define the IP range used for flannel overlay network, should not conflict
# with above SERVICE_CLUSTER_IP_RANGE.
# TODO: This is for jinjiang and allow only three machines right now.
FLANNEL_NET=172.24.60.0/22
FLANNEL_SUBNET_LEN=24
FLANNEL_SUBNET_MIN=172.24.61.0
FLANNEL_SUBNET_MAX=172.24.63.0
FLANNEL_TYPE="host-gw"

# The IP address for the Kubelet to serve on.
KUBELET_IP_ADDRESS=0.0.0.0

# MASTER_INSECURE_* is used to serve insecure connection. It is either
#   localhost, blocked by firewall, or use with nginx, etc.
# MASTER_SECURE_* is accessed directly from outside world, serving HTTPS.
# KUBELET_PORT is the port kubelet server serves on.
# Note, the above configs should rarely change.
MASTER_INSECURE_ADDRESS="127.0.0.1"
MASTER_INSECURE_PORT="8080"
MASTER_SECURE_ADDRESS="0.0.0.0"
MASTER_SECURE_PORT="443"
KUBELET_PORT="10250"

# -----------------------------------------------------------------------------
# Misc static configurations.
# -----------------------------------------------------------------------------
# Admission Controllers to invoke prior to persisting objects in cluster.
ADMISSION_CONTROL=NamespaceLifecycle,NamespaceExists,LimitRanger,ServiceAccount,ResourceQuota

# The infra container used for every Pod.
POD_INFRA_CONTAINER="caicloudgcr/pause:1.0"

# Namespace used to create cluster wide services, e.g. logging, dns, etc.
# The name is from upstream and shouldn't be changed.
SYSTEM_NAMESPACE="kube-system"

# Extra options to set on the Docker command line.  This is useful for setting
# --insecure-registry for local registries.
DOCKER_OPTS=""


# -----------------------------------------------------------------------------
# Derived params for kube-up (calculated based on above params: DO NOT CHANGE).
# If above configs are changed manually, remember to call the function.
# -----------------------------------------------------------------------------
function calculate-default {
  # If KUBE_USER is specified, set the path to save per user k8s config file;
  # otherwise, use default one from k8s.
  if [[ ! -z ${KUBE_USER-} ]]; then
    KUBECONFIG="$HOME/.kube/config_${KUBE_USER}"
  fi

  # Master IP and node IPs.
  MASTER_IP=${MASTER_SSH_INFO#*@}
  NODE_IPS=""
  IFS=',' read -ra node_info_array <<< "${NODE_SSH_INFO}"
  for node_info in "${node_info_array[@]}"; do
    IFS=':@' read -ra ssh_info <<< "${node_info}"
    if [[ -z "${NODE_IPS-}" ]]; then
      NODE_IPS="${ssh_info[2]}"
    else
      NODE_IPS="${NODE_IPS},${ssh_info[2]}"
    fi
  done

  # Create node IP address array and NUM_MINIONS.
  IFS=',' read -ra NODE_IPS_ARR <<< "${NODE_IPS}"
  export NUM_MINIONS=${#NODE_IPS_ARR[@]}

  # Note that master_name and node_name are name of the instances in anchnet, which
  # is helpful to group instances; however, anchnet API works well with instance id,
  # so we provide instance id to kubernetes as nodename and hostname, which makes it
  # easy to query anchnet in kubernetes.
  MASTER_NAME="${CLUSTER_NAME}-master"
  NODE_NAME_PREFIX="${CLUSTER_NAME}-node"

  # All instances' ssh info.
  INSTANCE_SSH_INFO="${MASTER_SSH_INFO},${NODE_SSH_INFO}"

  # Context to use in kubeconfig.
  CONTEXT="baremetal_${CLUSTER_NAME}"

  # Caicloud tarball package name.
  CAICLOUD_KUBE_PKG="caicloud-kube-${CAICLOUD_KUBE_VERSION}.tar.gz"

  # Final URL of caicloud tarball URL.
  CAICLOUD_TARBALL_URL="${CAICLOUD_HOST_URL}/${CAICLOUD_KUBE_PKG}"
}

calculate-default
