#!/bin/bash

# Copyright 2014 The Kubernetes Authors All rights reserved.
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

# The script is supposed to run at master instance to create addons.
# It looks for environment variables for enabling/disabling addons, e.g.
# ENABLE_CLUSTER_DNS, ENABLE_CLUSTER_LOGGING, etc, see config-default.sh.
# It is assumed that required addons yaml files are copied to ~/kube
# directory.

ENABLE_CLUSTER_DNS=${ENABLE_CLUSTER_DNS:-false}
ENABLE_CLUSTER_LOGGING=${ENABLE_CLUSTER_LOGGING:-false}
SYSTEM_NAMESPACE=${SYSTEM_NAMESPACE:-"kube-system"}

# Do retries when failing in objects creation from yaml files. It
# is assumed kubectl exists, i.e. /opt/bin/kubectl.
#
# Input:
#   $1 path to yaml file
#   $2 max retries
#   $3 delay between retries
#   $4 namespace in which the object should be created
function create-resource-from-file {
  config_file=$1
  tries=$2
  delay=$3
  namespace=$4
  while [ ${tries} -gt 0 ]; do
    /opt/bin/kubectl --namespace="${namespace}" create -f "${config_file}" && \
      echo "== Successfully started ${config_file} in namespace ${namespace} at $(date -Is)" && \
      return 0;
    let tries=tries-1;
    echo "== Failed to start ${config_file}. ${tries} tries remaining. =="
    sleep ${delay};
  done
  return 1;
}

# Orgnize yaml files and prepare creating addons.
function prepare-addons {
  # Create the namespace that will be used to host the cluster-level addons.
  mkdir -p ~/kube/namespace
  mv ~/kube/namespace.yaml ~/kube/namespace
  create-resource-from-file ~/kube/namespace/namespace.yaml 100 10 "default"
  # DNS addon.
  mkdir -p ~/kube/addons/dns
  mv ~/kube/skydns-rc.yaml ~/kube/skydns-svc.yaml ~/kube/addons/dns
  # Logging addon.
  mkdir -p ~/kube/addons/logging
  mv ~/kube/elasticsearch-rc.yaml ~/kube/elasticsearch-svc.yaml ~/kube/addons/logging
  mv ~/kube/kibana-rc.yaml ~/kube/kibana-svc.yaml ~/kube/addons/logging
}

function create-dns-addon {
  for obj in $(find ~/kube/addons/dns -type f -name \*.yaml -o -name \*.json); do
    create-resource-from-file ${obj} 10 10 "${SYSTEM_NAMESPACE}"
  done
}

function create-logging-addon {
  for obj in $(find ~/kube/addons/logging -type f -name \*.yaml -o -name \*.json); do
    create-resource-from-file ${obj} 10 10 "${SYSTEM_NAMESPACE}"
  done
}


prepare-addons

if [[ "${ENABLE_CLUSTER_DNS}" == "true" ]]; then
  create-dns-addon
fi

if [[ "${ENABLE_CLUSTER_LOGGING}" == "true" ]]; then
  create-logging-addon
fi
