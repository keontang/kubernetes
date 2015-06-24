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

# Deploy add-on services after cluster is available.

set -e

# Note the DNS addon has to be a lower version because of the semi-manual setup.
# We should be able to use newest version once we salt.
KUBE_ROOT=$(dirname "${BASH_SOURCE}")/../../..
source ${KUBE_ROOT}/cluster/anchnet/config-default.sh

if [[ "$(which kubectl)" == "" ]]; then
  echo "Can't find kubectl binary in PATH, please fix and retry"
  exit 1
fi

if [ "${ENABLE_CLUSTER_DNS}" == true ]; then
  echo "Deploying DNS on kubernetes"
  # Use kubectl to create skydns rc and service.
  kubectl create -f ${KUBE_ROOT}/cluster/anchnet/addons/skydns-rc.yaml
  kubectl create -f ${KUBE_ROOT}/cluster/anchnet/addons/skydns-svc.yaml
fi
