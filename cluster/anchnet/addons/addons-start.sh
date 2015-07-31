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

SYSTEM_NAMESPACE=kube-system

# Do retries when failing in objects creation from yaml files.
#
# $1 path to yaml file
# $2 max retries
# $3 delay between retries
# $4 namespace in which the object should be created
function create_resource_from_file() {
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

# Currently we put secrets, addons and namespace in separate folders
mkdir -p ~/kube/addons ~/kube/namespace ~/kube/secrets
mv ~/kube/skydns-rc.yaml ~/kube/skydns-svc.yaml ~/kube/addons
mv ~/kube/namespace.yaml ~/kube/namespace

# Create the namespace that will be used to host the cluster-level add-ons.
create_resource_from_file ~/kube/namespace/namespace.yaml 100 10 ""

# Create addons from file
for obj in $(find ~/kube/addons -type f -name \*.yaml -o -name \*.json); do
  create_resource_from_file ${obj} 10 10 "${SYSTEM_NAMESPACE}"
done
