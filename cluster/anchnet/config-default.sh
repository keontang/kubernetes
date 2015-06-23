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

## Contains configuration values for the Ubuntu cluster

# Define number of nodes (minions). There will be only one master.
export NUM_MINIONS=${NUM_MINIONS:-2}
# Define the IP range used for service cluster IPs.
export SERVICE_CLUSTER_IP_RANGE=192.168.3.0/24  # formerly PORTAL_NET
# Define the IP range used for flannel overlay network, should not conflict with above SERVICE_CLUSTER_IP_RANGE
export FLANNEL_NET=172.16.0.0/16
# Define the private SDN network name in anchnet.
export VXNET_NAME="caicloud"
# Define the internal IPs for instances in the above private SDN network.
# TODO: Make it easier to specify internal IPs. There can be a specific
#   pattern here, e.g. node IP starts from 10.244.1.0 and increment by 1
#   for subsequent nodes. So a helper shell function should suffice.
export INTERNAL_IP_RANGE=10.244.0.1/16
export INTERNAL_IP_MASK="255.255.0.0"
export MASTER_INTERNAL_IP="10.244.0.1"
export NODE_INTERNAL_IPS="10.244.1.0,10.244.1.1"

# Admission Controllers to invoke prior to persisting objects in cluster
ADMISSION_CONTROL=NamespaceLifecycle,NamespaceAutoProvision,LimitRanger,ServiceAccount,ResourceQuota

# The infra container used for every Pod.
POD_INFRA_CONTAINER="ddysher/k8s-pause:0.8.0"

# Optional: Install node monitoring.
ENABLE_NODE_MONITORING=true

# Optional: Enable node logging.
ENABLE_NODE_LOGGING=false
LOGGING_DESTINATION=elasticsearch

# Optional: When set to true, Elasticsearch and Kibana will be setup as part of the cluster bring up.
ENABLE_CLUSTER_LOGGING=false
ELASTICSEARCH_LOGGING_REPLICAS=1

# Optional: When set to true, heapster, Influxdb and Grafana will be setup as part of the cluster bring up.
ENABLE_CLUSTER_MONITORING="${KUBE_ENABLE_CLUSTER_MONITORING:-true}"

# Extra options to set on the Docker command line.  This is useful for setting
# --insecure-registry for local registries.
DOCKER_OPTS=""

# Optional: Install cluster DNS.
ENABLE_CLUSTER_DNS=true
# DNS_SERVER_IP must be a IP in SERVICE_CLUSTER_IP_RANGE
DNS_SERVER_IP="192.168.3.100"
DNS_DOMAIN="cluster.local"
DNS_REPLICAS=1

# Optional: Enable setting flags for kube-apiserver to turn on behavior in active-dev
#RUNTIME_CONFIG=""
