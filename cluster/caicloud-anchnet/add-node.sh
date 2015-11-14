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

set -o nounset
set -o pipefail

source "${KUBE_ROOT}/cluster/caicloud-anchnet/config-default.sh"
source "${KUBE_ROOT}/cluster/caicloud-anchnet/util.sh"
source "${KUBE_ROOT}/cluster/caicloud/common.sh"
source "${KUBE_ROOT}/cluster/caicloud/executor-service.sh"
source "${KUBE_ROOT}/cluster/caicloud/${KUBE_DISTRO}/helper.sh"

# TODO: This could be different for other distros
PRIVATE_SDN_INTERFACE="eth1"

function kube-add-nodes {
  log "+++++ Running kube-add-nodes ..."
  (set -o posix; set)

  # Get info about all instances in current cluster
  # NOTE: some of the vars, like nodes/instances related vars, will be reset afterwards
  # in create-new-nodes and compute-new-node-iips
  find-instance-and-eip-resouces "running"

  # Make sure we have:
  #  1. a staging area
  #  2. ssh capability
  #  3. log directory
  ensure-temp-dir
  ensure-ssh-agent
  ensure-log-dir

  # Create nodes from scratch.
  # create-new-nodes
  create-node-instances "${NUM_MINIONS}"

  # Clean up created node if we failed after new nodes are created.
  trap-add 'clean-up-failed-nodes' EXIT

  # Add newly created nodes to sdn network.
  join-sdn-network

  # Add newly created nodes to security group
  join-node-securitygroup

  # Set NODE_IIPS for newly created nodes
  create-node-internal-ips-variable

  # Set MASTER_INSTANCE_ID
  create-resource-variables

  trap-add 'clean-up-working-dir "${MASTER_SSH_EXTERNAL}" "${NODE_SSH_EXTERNAL}"' EXIT

  # Setup network
  setup-node-network

  # We have the binaries stored at master during kube-up, so we just fetch
  # tarball from master.
  local pids=""
  install-binaries-from-master \
    "${MASTER_SSH_EXTERNAL}" \
    "${NODE_SSH_EXTERNAL}" \
    "${NODE_SSH_INTERNAL}" & pids="$pids $!"
  install-packages \
    "${NODE_SSH_EXTERNAL}" & pids="$pids $!"
  wait $pids

  # Place kubelet-kubeconfig and kube-proxy-kubeconfig in working dir
  ssh-to-instance \
    "${MASTER_SSH_EXTERNAL}" \
    "sudo cp /etc/caicloud/kubelet-kubeconfig /etc/caicloud/kube-proxy-kubeconfig ~/kube"

  send-node-startup-config-files \
    "${MASTER_SSH_EXTERNAL}" \
    "${NODE_SSH_EXTERNAL}" \
    "${MASTER_IIP}" \
    "${PRIVATE_SDN_INTERFACE}" \
    "${NODE_INSTANCE_IDS}" \
    "anchnet" \
    "${ANCHNET_CONFIG_FILE}"

  start-node-kubernetes "${NODE_SSH_EXTERNAL}"
}

# TODO: report ip/id of newly created instances. The situation is slightly different
# from kube-up. We don't want to report created nodes before we successfully added
# them to cluster.
function report-new-nodes {
  echo "Reporting to... wait a sec, we have not implemented this yet!"
}

# Remove created node if we failed to add nodes to cluster
#
# Assumed vars:
#   NODE_INSTANCE_IDS
#   NODE_EIP_IDS
function clean-up-failed-nodes {
  # Only do cleanups when we failed to add node to cluster.
  if [[ $? == 0 ]]; then
    return
  fi
  if [[ ! -z "${NODE_INSTANCE_IDS}" ]]; then
    anchnet-exec-and-retry "${ANCHNET_CMD} terminateinstances ${NODE_INSTANCE_IDS} --project=${PROJECT_ID}"
    anchnet-wait-job ${COMMAND_EXEC_RESPONSE} ${INSTANCE_TERMINATE_WAIT_RETRY} ${INSTANCE_TERMINATE_WAIT_INTERVAL}
  fi
  if [[ ! -z "${NODE_EIP_IDS}" ]]; then
    anchnet-exec-and-retry "${ANCHNET_CMD} releaseeips ${NODE_EIP_IDS} --project=${PROJECT_ID}"
    anchnet-wait-job ${COMMAND_EXEC_RESPONSE} ${EIP_RELEASE_WAIT_RETRY} ${EIP_RELEASE_WAIT_INTERVAL}
  fi
}
