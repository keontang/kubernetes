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

# Define the IP range used for service cluster IPs. If this is ever changed,
# fixed cluster service IP needs to be changed as well, including DNS_SERVER_IP.
SERVICE_CLUSTER_IP_RANGE=10.254.0.0/16  # formerly PORTAL_NET
# Define the IP range used for flannel overlay network, should not conflict with above SERVICE_CLUSTER_IP_RANGE
FLANNEL_NET=172.16.0.0/12
# Define the private SDN network name in anchnet.
VXNET_NAME="caicloud"
# Define the internal IPs for instances in the above private SDN network.
INTERNAL_IP_RANGE=10.244.0.0/16
INTERNAL_IP_MASK=255.255.0.0
MASTER_INTERNAL_IP=10.244.0.1
NODE_INTERNAL_IP_RANGE=10.244.1.0/16


# MASTER_INSECURE_* is used to serve insecure connection. It is either
# localhost, blocked by firewall, or use with nginx, etc. MASTER_SECURE_*
# is accessed directly from outside world, serving HTTPS. Thses configs
# should rarely change.
MASTER_INSECURE_ADDRESS="127.0.0.1"
MASTER_INSECURE_PORT=8080
MASTER_SECURE_ADDRESS="0.0.0.0"
MASTER_SECURE_PORT=443

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
DNS_SERVER_IP=10.254.0.100
DNS_DOMAIN="cluster.local"
DNS_REPLICAS=1

# Optional: Enable setting flags for kube-apiserver to turn on behavior in active-dev
#RUNTIME_CONFIG=""
