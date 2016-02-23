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

# In kube-up.sh, bash is set to exit on error. However, we need to retry
# on error. Therefore, we disable errexit here.
set +o errexit

KUBE_ROOT="$(dirname "${BASH_SOURCE}")/../.."

# Get cluster configuration parameters from config-default, as well as all
# other utilities. Note KUBE_DISTRO will be available after sourcing file
# config-default.sh.
source "${KUBE_ROOT}/cluster/caicloud-baremetal/config-default.sh"
source "${KUBE_ROOT}/cluster/caicloud/common.sh"
source "${KUBE_ROOT}/cluster/caicloud/executor-service.sh"
source "${KUBE_ROOT}/cluster/caicloud/${KUBE_DISTRO}/helper.sh"


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
  # Print all environment and local variables at this point.
  log "+++++ Running kube-up with variables ..."
  (set -o posix; set)
  KUBE_UP=Y && (set -o posix; set)

  # Make sure we have:
  #  1. a staging area
  #  2. a public/private key pair used to provision instances.
  ensure-temp-dir
  ensure-ssh-agent

  setup-instances

  # Create certificates and credentials to secure cluster communication.
  create-certs-and-credentials

  # Concurrently install all packages for nodes.
  install-binaries-from-local
  install-packages "false"

  # Prepare master environment.
  send-master-startup-config-files
  send-node-startup-config-files

  # Now start kubernetes.
  start-kubernetes

  # Create config file, i.e. ~/.kube/config.
  source "${KUBE_ROOT}/cluster/common.sh"
  # create-kubeconfig assumes master ip is in the variable KUBE_MASTER_IP.
  # Also, in bare metal environment, we are deploying on master instance,
  # so we make sure it can find kubectl binary.
  export KUBE_MASTER_IP="${MASTER_IP}"
  create-kubeconfig
}

# Validate a kubernetes cluster
function validate-cluster {
  # by default call the generic validate-cluster.sh script, customizable by
  # any cluster provider if this does not fit.
  "${KUBE_ROOT}/cluster/validate-cluster.sh"

  echo "... calling deploy-addons" >&2
  deploy-addons "${MASTER_SSH_INFO}"
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
