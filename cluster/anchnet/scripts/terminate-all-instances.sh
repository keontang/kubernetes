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

set -o errexit
set -o nounset
set -o pipefail

# Release all instances (matching CLUSTER_ID) and their eips from anchnet.

KUBE_ROOT=$(dirname "${BASH_SOURCE}")/../../..
KUBERNETES_PROVIDER="anchnet"

source "${KUBE_ROOT}/cluster/kube-env.sh"
source "${KUBE_ROOT}/cluster/${KUBERNETES_PROVIDER}/util.sh"

# Find all instances prefixed with CLUSTER_ID.
anchnet-exec-and-retry "${ANCHNET_CMD} searchinstance ${CLUSTER_ID}"
count=$(echo ${ANCHNET_RESPONSE} | json_len '["item_set"]')

# Print instance information
echo -n "Found instances: "
for i in `seq 0 $(($count-1))`; do
  name=$(echo ${ANCHNET_RESPONSE} | json_val "['item_set'][$i]['instance_name']")
  id=$(echo ${ANCHNET_RESPONSE} | json_val "['item_set'][$i]['instance_id']")
  echo -n "${name},${id}; "
done
echo

# Build variables for terminating instances.
for i in `seq 0 $(($count-1))`; do
  instance_id=$(echo ${ANCHNET_RESPONSE} | json_val "['item_set'][$i]['instance_id']")
  eip_id=$(echo ${ANCHNET_RESPONSE} | json_val "['item_set'][$i]['eip']['eip_id']")
  if [[ -z "${ALL_INSTANCES-}" ]]; then
    ALL_INSTANCES="${instance_id}"
  else
    ALL_INSTANCES="${ALL_INSTANCES},${instance_id}"
  fi
  if [[ -z "${ALL_EIPS-}" ]]; then
    ALL_EIPS="${eip_id}"
  else
    ALL_EIPS="${ALL_EIPS},${eip_id}"
  fi
done

# Executing commands.
anchnet-exec-and-retry "anchnet terminateinstances ${ALL_INSTANCES}"
anchnet-wait-job ${ANCHNET_RESPONSE} 120 6
anchnet-exec-and-retry "anchnet releaseeips ${ALL_EIPS}"
anchnet-wait-job ${ANCHNET_RESPONSE} 120 6
