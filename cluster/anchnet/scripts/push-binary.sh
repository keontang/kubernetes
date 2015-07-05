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

# Set this to internal IPs of all the instances.
INSTANCE_IPS="10.57.46.195,10.57.47.48,10.57.52.35"
KUBE_INSTANCE_PASSWORD="caicloud2015ABC"


KUBE_ROOT=$(dirname "${BASH_SOURCE}")/../../..
source "${KUBE_ROOT}/cluster/anchnet/util.sh"
source "${KUBE_ROOT}/hack/build-go.sh"

IFS=',' read -ra instance_ip_arr <<< "${INSTANCE_IPS}"
for instance_ip in ${instance_ip_arr[*]}; do
  expect <<EOF
set timeout -1
spawn scp -r -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
  ${KUBE_ROOT}/_output/local/bin/linux/amd64/kube-controller-manager \
  ${KUBE_ROOT}/_output/local/bin/linux/amd64/kube-apiserver \
  ${KUBE_ROOT}/_output/local/bin/linux/amd64/kube-scheduler \
  ubuntu@${instance_ip}:~/kube/master
expect "*assword*"
send -- "${KUBE_INSTANCE_PASSWORD}\r"
expect eof
EOF
  expect <<EOF
set timeout -1
spawn scp -r -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
  ${KUBE_ROOT}/_output/local/bin/linux/amd64/kubelet \
  ${KUBE_ROOT}/_output/local/bin/linux/amd64/kubectl \
  ${KUBE_ROOT}/_output/local/bin/linux/amd64/kube-proxy \
  ubuntu@${instance_ip}:~/kube/node
expect "*assword*"
send -- "${KUBE_INSTANCE_PASSWORD}\r"
expect eof
EOF
done
