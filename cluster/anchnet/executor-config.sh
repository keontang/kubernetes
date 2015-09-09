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

# The file contains configuration values that vary per user. Some values
# are specified by users, e.g. NODE_MEM; and some values are specified by
# cluster executor, e.g. CLUSTER_NAME.

# -----------------------------------------------------------------------------
# Params from executor for kube-up.

# Label of the cluster. This is used for constructing the prefix of resource
# ids from anchnet. The same label needs to be specified when running
# kube-down to release the resources acquired during kube-up.
CLUSTER_NAME=${CLUSTER_NAME:-"kube-default"}

# Project id actually stands for an anchnet sub-account. If PROJECT_ID is
# not set, all the subsequent anchnet calls will use the default account.
PROJECT_ID=${PROJECT_ID:-""}

# KUBE_USER uniquely identifies a caicloud user.
KUBE_USER=${KUBE_USER:-""}

# INITIAL_DEPOSIT is the money transferred to sub account upon creation
INITIAL_DEPOSIT=${INITIAL_DEPOSIT:-"1"}

# To indicate if the execution status needs to be reported back to Caicloud
# executor via curl. Set it to be Y if reporting is needed.
REPORT_KUBE_STATUS=${REPORT_KUBE_STATUS:-"N"}

# Number of retries and interval (in second) for waiting master creation job.
# Adjust the value based on the number of master instances created.
MASTER_WAIT_RETRY=${MASTER_WAIT_RETRY:-120}
MASTER_WAIT_INTERVAL=${MASTER_WAIT_INTERVAL:-3}

# Number of retries and interval (in second) for waiting nodes creation job.
# Adjust the value based on the number of node instances created.
NODES_WAIT_RETRY=${NODES_WAIT_RETRY:-240}
NODES_WAIT_INTERVAL=${NODES_WAIT_INTERVAL:-3}

# Number of retries and interval (in second) for waiting vxnet creation job.
# The value doesn't need to be changed theoretically.
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
USER_PROJECT_WAIT_RETRY=${USER_PROJECT_WAIT_RETRY:-120}
USER_PROJECT_WAIT_INTERVAL=${USER_PROJECT_WAIT_INTERVAL:-3}

# -----------------------------------------------------------------------------
# Params from user for kube-up.

# Define number of nodes (minions). There will be only one master.
NUM_MINIONS=${NUM_MINIONS:-1}

# The memory size of master node (in MB).
MASTER_MEM=${MASTER_MEM:-1024}
# The number of CPUs of the master.
MASTER_CPU_CORES=${MASTER_CPU_CORES:-1}

# The memory size of master node (in MB).
NODE_MEM=${NODE_MEM:-1024}
# The number of CPUs of a node.
NODE_CPU_CORES=${NODE_CPU_CORES:-1}

# -----------------------------------------------------------------------------
# Derived params for kube-up (calculated based on above params).

# Note that master_name and node_name are name of the instances in anchnet, which
# is helpful to group instances; however, anchnet API works well with instance id,
# so we provide instance id to kubernetes as nodename and hostname, which makes it
# easy to query anchnet in kubernetes.
MASTER_NAME="${CLUSTER_NAME}-master"
NODE_NAME_PREFIX="${CLUSTER_NAME}-node"

# If KUBE_USER is specified, set the path to save per user k8s config file;
# otherwise, use default one from k8s.
if [[ ! -z ${KUBE_USER-} ]]; then
  KUBECONFIG="$HOME/.kube/config_${KUBE_USER}"
fi
CONTEXT="anchnet_${CLUSTER_NAME}"

# -----------------------------------------------------------------------------
# Params from executor for kube-down.

# Number of retries and interval (in second) for waiting instance terminate job.
# Adjust the value based on the number of instances created
INSTANCE_TERMINATE_WAIT_RETRY=${INSTANCE_TERMINATE_WAIT_RETRY:-240}
INSTANCE_TERMINATE_WAIT_INTERVAL=${INSTANCE_TERMINATE_WAIT_INTERVAL:-6}

# Number of retries and interval (in second) for waiting eip release job.
# Adjust the value based on the number of eips created
EIP_RELEASE_WAIT_RETRY=${EIP_RELEASE_WAIT_RETRY:-240}
EIP_RELEASE_WAIT_INTERVAL=${EIP_RELEASE_WAIT_INTERVAL:-6}

# Number of retries and interval (in second) for waiting vxnet delete job.
# Adjust the value based on the number of instances created
VXNET_DELETE_WAIT_RETRY=${VXNET_DELETE_WAIT_RETRY:-240}
VXNET_DELETE_WAIT_INTERVAL=${VXNET_DELETE_WAIT_INTERVAL:-6}

# Number of retries and interval (in second) for waiting SG delete job.
# Adjust the value based on the number of instances created
SG_DELETE_WAIT_RETRY=${SG_DELETE_WAIT_RETRY:-240}
SG_DELETE_WAIT_INTERVAL=${SG_DELETE_WAIT_INTERVAL:-6}
