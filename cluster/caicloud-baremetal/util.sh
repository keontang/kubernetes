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

# Caicloud baremetal cloudprovider.

KUBE_ROOT=$(dirname "${BASH_SOURCE}")/../..

# Get cluster configuration parameters from config-default, as well as all
# other utilities. Note KUBE_DISTRO will be available after sourcing file
# config-default.sh.
function setup-cluster-env {
  source "${KUBE_ROOT}/cluster/caicloud/common.sh"
  source "${KUBE_ROOT}/cluster/caicloud-baremetal/config-default.sh"
  source "${KUBE_ROOT}/cluster/caicloud/${KUBE_DISTRO}/helper.sh"
}

setup-cluster-env

# -----------------------------------------------------------------------------
# Cluster specific library utility functions.
# -----------------------------------------------------------------------------
# Verify cluster prerequisites.
function verify-prereqs {
  if [[ "$(which curl)" == "" ]]; then
    log "Can't find curl in PATH, please fix and retry."
    exit 1
  fi
  if [[ "$(which expect)" == "" ]]; then
    log "Can't find expect binary in PATH, please fix and retry."
    exit 1
  fi
}

# Instantiate a kubernetes cluster
function kube-up {
  # Make sure we have:
  #  1. a staging area
  #  2. a public/private key pair used to provision instances.
  ensure-temp-dir
  ensure-pub-key

  # Get the caicloud kubernetes release tarball.
  fetch-and-extract-tarball

  # Create certificates and credentials to secure cluster communication.
  create-certs-and-credentials "${MASTER_IP}"

  # Randomly choose one daocloud accelerator.
  find-registry-mirror

  # Concurrently install all packages for nodes.
  local pids=""
  for (( i = 0; i < $(($NUM_MINIONS)); i++ )); do
    local node_ip=${NODE_IPS_ARR[${i}]}
    install-packages "${INSTANCE_USER}@${node_ip}" "${KUBE_INSTANCE_PASSWORD}" & pids="${pids} $!"
  done
  wait ${pids}

  # Prepare master environment.
  create-master-start-script "${KUBE_TEMP}/master-start.sh" "${MASTER_IP}"
  send-files-to-master "${INSTANCE_USER}@${MASTER_IP}" "${KUBE_INSTANCE_PASSWORD}"

  # Prepare node environment.
  for (( i = 0; i < $(($NUM_MINIONS)); i++ )); do
    local node_ip=${NODE_IPS_ARR[${i}]}
    mkdir -p ${KUBE_TEMP}/node${i}
    create-node-start-script "${KUBE_TEMP}/node${i}/node-start.sh" "${MASTER_IP}" "${REG_MIRROR}" "${node_ip}"
    send-files-to-node "${INSTANCE_USER}@${node_ip}" "${KUBE_INSTANCE_PASSWORD}"
  done

  # Now start kubernetes.
  start-kubernetes "${MASTER_IP}" "${NODE_IPS_ARR}" "${KUBE_INSTANCE_PASSWORD}"

  # Create config file, i.e. ~/.kube/config.
  source "${KUBE_ROOT}/cluster/common.sh"
  KUBE_MASTER_IP="${MASTER_IP}"
  create-kubeconfig
}

# Validate a kubernetes cluster
function validate-cluster {
  # by default call the generic validate-cluster.sh script, customizable by
  # any cluster provider if this does not fit.
  "${KUBE_ROOT}/cluster/validate-cluster.sh"

  echo "... calling deploy-addons" >&2
  deploy-addons "${INSTANCE_USER}@${MASTER_IP}" "${KUBE_INSTANCE_PASSWORD}"
}

# Delete a kubernetes cluster
function kube-down {
  echo "TODO: kube-down" 1>&2
}

# Must ensure that the following ENV vars are set
function detect-master {
  echo "KUBE_MASTER_IP: $KUBE_MASTER_IP" 1>&2
  echo "KUBE_MASTER: $KUBE_MASTER" 1>&2
}

# Get minion names if they are not static.
function detect-minion-names {
  echo "MINION_NAMES: [${MINION_NAMES[*]}]" 1>&2
}

# Get minion IP addresses and store in KUBE_MINION_IP_ADDRESSES[]
function detect-minions {
  echo "KUBE_MINION_IP_ADDRESSES: [${KUBE_MINION_IP_ADDRESSES[*]}]" 1>&2
}
