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

source "${KUBE_ROOT}/cluster/caicloud-baremetal/config-default.sh"
source "${KUBE_ROOT}/cluster/caicloud-baremetal/util.sh"
source "${KUBE_ROOT}/cluster/caicloud/common.sh"
source "${KUBE_ROOT}/cluster/caicloud/executor-service.sh"
source "${KUBE_ROOT}/cluster/caicloud/${KUBE_DISTRO}/helper.sh"

function kube-add-nodes {
  log "+++++ Running kube-add-nodes ..."
  (set -o posix; set)

  # Make sure we have:
  #  1. a staging area
  #  2. ssh capability
  ensure-temp-dir
  ensure-ssh-agent

  # Set up new nodes.
  IFS=',' read -ra node_ssh_info <<< "${NODE_SSH_EXTERNAL}"
  for (( i = 0; i < ${#node_ssh_info[*]}; i++ )); do
    IFS=':@' read -ra ssh_info <<< "${node_ssh_info[$i]}"
    setup-instance "${ssh_info[2]}" "${ssh_info[0]}" "${ssh_info[1]}"
  done

  # Clean up created node if we failed after new nodes are created.
  trap-add 'clean-up-working-dir "${MASTER_SSH_EXTERNAL}" "${NODE_SSH_EXTERNAL}"' EXIT

  # We have the binaries stored at master during kube-up, so we just fetch
  # tarball from master.
  local pids=""
  install-binaries-from-master & pids="$pids $!"
  install-packages & pids="$pids $!"
  wait $pids

  # Place kubelet-kubeconfig and kube-proxy-kubeconfig in working dir.
  ssh-to-instance \
    "${MASTER_SSH_EXTERNAL}" \
    "sudo cp /etc/caicloud/kubelet-kubeconfig /etc/caicloud/kube-proxy-kubeconfig ~/kube"

  # Send node config files and start the node.
  send-node-files
  start-node-kubernetes
}

# No need to report for baremetal cluster
function report-new-nodes {
  echo "Nothing to be reported for baremetal"
}
