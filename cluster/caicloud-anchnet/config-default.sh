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
# KUBE_UP_MODE defines how to run kube-up, there are currently three modes:
#
# - "tarball": In tarball mode, kube binaries and non-kube binaries are built
#   as a single tarball. There are two different behaviors in tarball mode:
#   - If BUILD_TARBALL is N, we build current code base and push to remote host,
#     using script hack/caicloud/build-tarball.sh.
#   - If BUILD_TARBALL is Y, then we simply fetch from remote host.
#
# - "image": In image mode, we use pre-built custom image. It is assumed that
#   the custom image has all binaries and packages installed, i.e. kube binaries,
#   non-kube binaries, docker, bridge-utils, etc. Image mode is the fastest mode,
#   but requires we pre-built the image and requires the image is accessible for
#   all sub account. This is currently not possible in anchnet, since every sub
#   account can only see its own custom image.
#
# - "dev": In dev mode, no machine will be created. Developer is responsible to
#   specify the master instance ID and node instance IDs. This is primarily used
#   for debugging kube-up.sh script itself to avoid repeatly creating resources.
KUBE_UP_MODE=${KUBE_UP_MODE:-"tarball"}

# Linux distribution of underline machines.
KUBE_DISTRO=${KUBE_DISTRO:-"trusty"}

# Name of the cluster. This is used for constructing the prefix of resource IDs
# in anchnet. The same name needs to be specified when running kube-down to
# release the resources acquired during kube-up.
CLUSTER_NAME=${CLUSTER_NAME:-"kube-default"}

# Decide if building release is needed. If the parameter is true, then use
# BUILD_VERSION as release version; otherwise, use CAICLOUD_KUBE_VERSION. Using
# two different versions avoid overriding existing release.
BUILD_TARBALL=${BUILD_TARBALL:-"N"}

# The version of newly built release during kube-up.
BUILD_VERSION=${BUILD_VERSION:-"`TZ=Asia/Shanghai date +%Y-%m-%d-%H-%M-%S`"}

# The version of caicloud release to use if building release is not required.
# E.g. v1.0.2, 2015-09-09-15-30-30, etc.
CAICLOUD_KUBE_VERSION=${CAICLOUD_KUBE_VERSION:-"v0.5.0"}

# SUB_ACCOUNT_USER uniquely identifies a caicloud user. This is the user that owns the
# cluster, and will be used to create kubeconfig file.
SUB_ACCOUNT_USER=${SUB_ACCOUNT_USER:-""}

# Project ID actually stands for anchnet sub-account. If PROJECT_ID and KUBE_USER
# are not set, all the subsequent anchnet calls will use main account in anchnet.
PROJECT_ID=${PROJECT_ID:-""}

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

# The base image used to create master and node instance in image mode. The
# param is only used in image mode. This image is created from scripts like
# 'image-from-devserver.sh'.
IMAGEMODE_IMAGE=${IMAGEMODE_IMAGE:-"img-C0SA7DD5"}

# The base image used to create master and node instance in non-image modes.
RAW_BASE_IMAGE=${RAW_BASE_IMAGE:-"trustysrvx64c"}

# Instance user and password, for all cluster machines.
INSTANCE_USER=${INSTANCE_USER:-"ubuntu"}
KUBE_INSTANCE_PASSWORD=${KUBE_INSTANCE_PASSWORD:-"caicloud2015ABC"}

# The user & password without sudo privilege
LOGIN_USER=${LOGIN_USER:-"caicloud"}
LOGIN_PWD=${LOGIN_PWD:-"caiyun12345678"}

# To indicate if the execution status needs to be reported back to caicloud
# executor via curl. Set it to be Y if reporting is needed.
REPORT_KUBE_STATUS=${REPORT_KUBE_STATUS:-"N"}

# Money transferred to sub account upon its creation.
INITIAL_DEPOSIT=${INITIAL_DEPOSIT:-"1"}

# The IP Group used for new instances. 'eipg-98dyd0aj' is China Telecom and
# 'eipg-00000000' is anchnet's own BGP. Usually, we just use BGP.
IP_GROUP=${IP_GROUP:-"eipg-00000000"}

# Define the private SDN network name in anchnet.
VXNET_NAME=${VXNET_NAME:-"caicloud"}

# Define master/node security group name.
MASTER_SG_NAME=${MASTER_SG_NAME:-"master-sg"}
NODE_SG_NAME=${NODE_SG_NAME:-"node-sg"}

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

# Number of retries and interval (in second) for waiting master creation job.
# Adjust the value based on the number of master instances created.
MASTER_WAIT_RETRY=${MASTER_WAIT_RETRY:-120}
MASTER_WAIT_INTERVAL=${MASTER_WAIT_INTERVAL:-3}

# Number of retries and interval (in second) for waiting nodes creation job.
# Adjust the value based on the number of node instances created.
NODES_WAIT_RETRY=${NODES_WAIT_RETRY:-240}
NODES_WAIT_INTERVAL=${NODES_WAIT_INTERVAL:-3}

# Number of retries and interval (in second) for waiting vxnet creation job.
# Theoretically, The value doesn't need to be changed since we only create
# one vxnet during kube-up.
VXNET_CREATE_WAIT_RETRY=${VXNET_CREATE_WAIT_RETRY:-60}
VXNET_CREATE_WAIT_INTERVAL=${VXNET_CREATE_WAIT_INTERVAL:-3}

# Number of retries and interval (in second) for waiting vxnet join job.
# Adjust the value based on the number of all instances.
VXNET_JOIN_WAIT_RETRY=${VXNET_JOIN_WAIT_RETRY:-60}
VXNET_JOIN_WAIT_INTERVAL=${VXNET_JOIN_WAIT_INTERVAL:-3}

# Number of retries and interval (in second) for waiting master security group job.
# Adjust the value based on the number of master instances created, and number
# of security group rules.
SG_MASTER_WAIT_RETRY=${SG_MASTER_WAIT_RETRY:-120}
SG_MASTER_WAIT_INTERVAL=${SG_MASTER_WAIT_INTERVAL:-3}

# Number of retries and interval (in second) for waiting nodes security group job.
# Adjust the value based on the number of nodes instances created, and number
# of security group rules.
SG_NODES_WAIT_RETRY=${SG_NODES_WAIT_RETRY:-120}
SG_NODES_WAIT_INTERVAL=${SG_NODES_WAIT_INTERVAL:-3}

# Number of retries and interval (in second) for waiting user project job.
# Theoretically, The value doesn't need to be changed since we only create
# one project during kube-up.
USER_PROJECT_WAIT_RETRY=${USER_PROJECT_WAIT_RETRY:-120}
USER_PROJECT_WAIT_INTERVAL=${USER_PROJECT_WAIT_INTERVAL:-3}


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
# Params from user for kube-up.
# -----------------------------------------------------------------------------
# Define number of nodes (minions). There will be only one master.
NUM_MINIONS=${NUM_MINIONS:-2}

# Define number of nodes (minions) currently running in the cluster.
# For kube-up, this should be 0.
NUM_RUNNING_MINIONS=${NUM_RUNNING_MINIONS:-0}

# The memory size of master node (in MB).
MASTER_MEM=${MASTER_MEM:-1024}
# The number of CPUs of the master.
MASTER_CPU_CORES=${MASTER_CPU_CORES:-1}

# The memory size of master node (in MB).
NODE_MEM=${NODE_MEM:-1024}
# The number of CPUs of a node.
NODE_CPU_CORES=${NODE_CPU_CORES:-1}

# -----------------------------------------------------------------------------
# Params from executor for kube-down.
# -----------------------------------------------------------------------------
# Number of retries and interval (in second) for waiting instance terminate job.
# Adjust the value based on the number of instances created.
INSTANCE_TERMINATE_WAIT_RETRY=${INSTANCE_TERMINATE_WAIT_RETRY:-240}
INSTANCE_TERMINATE_WAIT_INTERVAL=${INSTANCE_TERMINATE_WAIT_INTERVAL:-6}

# Number of retries and interval (in second) for waiting eip release job.
# Adjust the value based on the number of eips created.
EIP_RELEASE_WAIT_RETRY=${EIP_RELEASE_WAIT_RETRY:-240}
EIP_RELEASE_WAIT_INTERVAL=${EIP_RELEASE_WAIT_INTERVAL:-6}

# Number of retries and interval (in second) for waiting vxnet delete job.
# Adjust the value based on the number of instances created.
VXNET_DELETE_WAIT_RETRY=${VXNET_DELETE_WAIT_RETRY:-240}
VXNET_DELETE_WAIT_INTERVAL=${VXNET_DELETE_WAIT_INTERVAL:-6}

# Number of retries and interval (in second) for waiting SG delete job.
# Adjust the value based on the number of instances created.
SG_DELETE_WAIT_RETRY=${SG_DELETE_WAIT_RETRY:-240}
SG_DELETE_WAIT_INTERVAL=${SG_DELETE_WAIT_INTERVAL:-6}


# -----------------------------------------------------------------------------
# Cluster IP address and ranges: all are static configuration values.
# -----------------------------------------------------------------------------
# Define the IP range used for service cluster IPs. If this is ever changed,
# fixed cluster service IP needs to be changed as well, including DNS_SERVER_IP.
SERVICE_CLUSTER_IP_RANGE=10.254.0.0/16  # formerly PORTAL_NET

# Define the IP range used for flannel overlay network, should not conflict
# with above SERVICE_CLUSTER_IP_RANGE.
FLANNEL_NET=172.16.0.0/12
FLANNEL_SUBNET_LEN=24
FLANNEL_SUBNET_MIN=172.16.0.0
FLANNEL_SUBNET_MAX=172.31.0.0
FLANNEL_TYPE="udp"

# The IP address for the Kubelet to serve on
KUBELET_IP_ADDRESS=0.0.0.0

# Define the internal IPs for instances in private SDN network.
INTERNAL_IP_RANGE=10.244.0.0/16
INTERNAL_IP_MASK=255.255.0.0
MASTER_IIP=10.244.0.1
NODE_IIP_RANGE=10.244.1.0/16

# MASTER_INSECURE_* is used to serve insecure connection. It is either
# localhost, blocked by firewall, or use with nginx, etc. MASTER_SECURE_*
# is accessed directly from outside world, serving HTTPS. Thses configs
# should rarely change.
MASTER_INSECURE_ADDRESS="127.0.0.1"
MASTER_INSECURE_PORT="8080"
MASTER_SECURE_ADDRESS="0.0.0.0"
MASTER_SECURE_PORT="443"
KUBELET_PORT="10250"

# -----------------------------------------------------------------------------
# Misc static configurations.
# -----------------------------------------------------------------------------
# Admission Controllers to invoke prior to persisting objects in cluster.
ADMISSION_CONTROL=NamespaceLifecycle,LimitRanger,SecurityContextDeny,ServiceAccount,ResourceQuota

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
  # Decide which image to use.
  if [[ "${KUBE_UP_MODE}" == "image" ]]; then
    FINAL_IMAGE=${IMAGEMODE_IMAGE}
  else
    FINAL_IMAGE=${RAW_BASE_IMAGE}
  fi

  # Decide which version to use.
  if [[ "${BUILD_TARBALL}" = "Y" ]]; then
    FINAL_VERSION=${BUILD_VERSION}
  else
    FINAL_VERSION=${CAICLOUD_KUBE_VERSION}
  fi

  # If SUB_ACCOUNT_USER is specified, set the path to save per cluster k8s config file;
  # otherwise, use default one from k8s.
  if [[ ! -z ${SUB_ACCOUNT_USER-} ]]; then
    KUBECONFIG="$HOME/.kube/config_${CLUSTER_NAME}"
  fi

  # Note that master_name and node_name are name of the instances in anchnet, which
  # is helpful to group instances; however, anchnet API works well with instance id,
  # so we provide instance id to kubernetes as nodename and hostname, which makes it
  # easy to query anchnet in kubernetes.
  MASTER_NAME="${CLUSTER_NAME}-master"
  NODE_NAME_PREFIX="${CLUSTER_NAME}-node"

  # Context to use in kubeconfig.
  CONTEXT="anchnet_${CLUSTER_NAME}"

  # Anchnet command alias.
  ANCHNET_CMD="anchnet --config-path=${ANCHNET_CONFIG_FILE}"

  # Caicloud tarball package name.
  CAICLOUD_KUBE_PKG="caicloud-kube-${FINAL_VERSION}.tar.gz"

  # Final URL of caicloud tarball URL.
  CAICLOUD_TARBALL_URL="${CAICLOUD_HOST_URL}/${CAICLOUD_KUBE_PKG}"
}

calculate-default
