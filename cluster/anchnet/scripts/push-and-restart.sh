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

# The script builds current code base, pushes binaries to remote machines,
# and restarts kubernetes.

# Set master and node internal IPs.
MASTER_IP="10.57.42.91"
NODE_IPS="10.57.42.68"
KUBE_INSTANCE_PASSWORD="caicloud2015ABC"
CLEAN_ETCD=false

KUBE_ROOT=$(dirname "${BASH_SOURCE}")/../../..
source "${KUBE_ROOT}/cluster/anchnet/util.sh"

# Build current codebase.
source "${KUBE_ROOT}/hack/build-go.sh"

# Push new binaries to master and nodes.
INSTANCE_IPS="${MASTER_IP},${NODE_IPS}"
IFS=',' read -ra instance_ip_arr <<< "${INSTANCE_IPS}"
for instance_ip in ${instance_ip_arr[*]}; do
  expect <<EOF
set timeout -1
spawn scp -r -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
  ${KUBE_ROOT}/_output/local/bin/linux/amd64/kube-controller-manager \
  ${KUBE_ROOT}/_output/local/bin/linux/amd64/kube-apiserver \
  ${KUBE_ROOT}/_output/local/bin/linux/amd64/kube-scheduler \
  ${KUBE_ROOT}/_output/local/bin/linux/amd64/kubectl \
  ubuntu@${instance_ip}:~/kube/master
expect {
  "*?assword:" {
    send -- "${KUBE_INSTANCE_PASSWORD}\r"
    exp_continue
  }
  eof {}
}
EOF
  expect <<EOF
set timeout -1
spawn scp -r -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
  ${KUBE_ROOT}/_output/local/bin/linux/amd64/kubelet \
  ${KUBE_ROOT}/_output/local/bin/linux/amd64/kubectl \
  ${KUBE_ROOT}/_output/local/bin/linux/amd64/kube-proxy \
  ubuntu@${instance_ip}:~/kube/node
expect {
  "*?assword:" {
    send -- "${KUBE_INSTANCE_PASSWORD}\r"
    exp_continue
  }
  eof {}
}
EOF
done

# Stop running cluster.
echo "Stop services..."
for instance_ip in ${instance_ip_arr[*]}; do
  expect <<EOF
set timeout -1
spawn ssh -t -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
  ubuntu@${instance_ip} "sudo service etcd stop"
expect {
  "*assword*" {
    send -- "${KUBE_INSTANCE_PASSWORD}\r"
    exp_continue
  }
  eof {}
}
EOF
done

# Clean etcd data.
if [[ "${CLEAN_ETCD}" == true ]]; then
echo "Cleanup etcd data..."
for instance_ip in ${instance_ip_arr[*]}; do
  expect <<EOF
set timeout -1
spawn ssh -t -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
  ubuntu@${instance_ip} "sudo rm -rf /kubernetes-*.etcd"
expect {
  "*assword*" {
    send -- "${KUBE_INSTANCE_PASSWORD}\r"
    exp_continue
  }
  eof {}
}
EOF
done
fi

# Restart cluster
pids=""
echo "Restart master..."
expect <<EOF &
set timeout -1
spawn ssh -t -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
  ubuntu@${MASTER_IP} "sudo ~/kube/master-start.sh"
expect {
  "*assword*" {
    send -- "${KUBE_INSTANCE_PASSWORD}\r"
    exp_continue
  }
  eof {}
}
EOF
pids="$pids $!"

IFS=',' read -ra node_ip_arr <<< "${NODE_IPS}"
i=0
for node_eip in "${node_ip_arr[@]}"; do
  echo "Restart node-${i}..."
  expect <<EOF &
set timeout -1
spawn ssh -t -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
  ubuntu@${node_eip} "sudo ./kube/node${i}-start.sh"
expect {
  "*assword*" {
    send -- "${KUBE_INSTANCE_PASSWORD}\r"
    exp_continue
  }
  eof {}
}
EOF
  pids="$pids $!"
  i=$(($i+1))
done

echo "Wait for all instances to be provisioned..."
wait $pids
echo "All instances have been provisioned..."
