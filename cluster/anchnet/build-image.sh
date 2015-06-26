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


# The script creates an instance with:
#   1. cluster binaries installed, with specified versions;
#   2. docker and bridge-utils installed
#
# The instance is supposed to be used to create a base image.

set -e

# Release version for different components used to create cluster. Make sure
# they all exist on their respective github release page.
ETCD_VERSION="v2.0.12"
FLANNEL_VERSION="0.4.0"
K8S_VERSION="v0.19.3"
DOCKER_VERSION="1.6.2"
KUBE_INSTANCE_PASSWORD="caicloud2015ABC"

KUBE_ROOT=$(dirname "${BASH_SOURCE}")/../..
source "${KUBE_ROOT}/cluster/anchnet/util.sh"


# Main function used to create the base image.
function main {
  verify-prereqs

  # Make sure we have a staging area.
  ensure-temp-dir

  # Make sure we have a public/private key pair used to provision the machine.
  ensure-pub-key

  download-release

  local instance_info=$(${ANCHNET_CMD} runinstance base-image -p="${KUBE_INSTANCE_PASSWORD}")
  local instance_id=$(echo ${instance_info} | json_val '["instances"][0]')
  local eip_id=$(echo ${instance_info} | json_val '["eips"][0]')

  check-instance-status "${instance_id}"
  get-ip-address-from-eipid "${eip_id}"
  local eip=${EIP_ADDRESS}

  # Enable ssh without password.
  setup-instance-ssh "${eip}"

  # Create a file used to install nodes. NOTE: The script will be ran multiple
  # times to make sure things are installed properly.
  (
    echo "cp ~/kube/common/* ~/kube/master"
    echo "cp ~/kube/common/* ~/kube/node"
    echo "sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 36A1D7869245C8950F966E92D8576A8BA88D21E9"
    echo "sudo sh -c \"echo deb https://get.docker.io/ubuntu docker main > /etc/apt/sources.list.d/docker.list\""
    echo "sudo apt-get update"
    echo "sudo apt-get install -y --force-yes lxc-docker-${DOCKER_VERSION}"
    echo "sudo apt-get install bridge-utils"
  ) > ${KUBE_TEMP}/install.sh
  chmod a+x ${KUBE_TEMP}/install.sh

  # Create working directory.
  ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
      "ubuntu@${eip}" "mkdir -p ~/kube"
  # Copy master/node components to the instance; can be very slow based on network.
  scp -r -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
      ${KUBE_TEMP}/master ${KUBE_TEMP}/node ${KUBE_TEMP}/common ${KUBE_TEMP}/install.sh \
      "ubuntu@${eip}":~/kube
  # Run the installation script twice.
  # TODO: Running the script can be very slow, so we may have password prompt again.
  expect <<EOF
set timeout -1
spawn ssh -t -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
  ubuntu@${eip} "sudo ~/kube/install.sh && sudo ~/kube/install.sh"
expect "*assword for*"
send -- "${KUBE_INSTANCE_PASSWORD}\r"
expect eof
EOF

  # Clean up unused files.
  ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
      "ubuntu@${eip}" "rm ~/kube/install.sh ~/.ssh/authorized_keys"
}


# Download release to a temp dir, organized by master, node and common. E.g.
#  /tmp/kubernetes.EuWJ4M/master
#  /tmp/kubernetes.EuWJ4M/node
#  /tmp/kubernetes.EuWJ4M/common
#
# TODO: We should use our own k8s release, of course :)
#
# Assumed vars:
#   ETCD_VERSION
#   FLANNEL_VERSION
#   K8S_VERSION
#
# Vars set:
#   KUBE_TEMP (call to ensure-temp-dir)
function download-release {
  ensure-temp-dir

  mkdir "${KUBE_TEMP}"/master
  mkdir "${KUBE_TEMP}"/node
  mkdir "${KUBE_TEMP}"/common

  (cd "${KUBE_TEMP}"
   echo "Download flannel release ..."
   if [ ! -f flannel.tar.gz ] ; then
     curl -L  https://github.com/coreos/flannel/releases/download/v${FLANNEL_VERSION}/flannel-${FLANNEL_VERSION}-linux-amd64.tar.gz -o flannel.tar.gz
     tar xzf flannel.tar.gz
   fi
   # Put flanneld in master also we can use kubectl proxy.
   cp flannel-${FLANNEL_VERSION}/flanneld common

   echo "Download etcd release ..."
   ETCD="etcd-${ETCD_VERSION}-linux-amd64"
   if [ ! -f etcd.tar.gz ] ; then
     curl -L https://github.com/coreos/etcd/releases/download/${ETCD_VERSION}/${ETCD}.tar.gz -o etcd.tar.gz
     tar xzf etcd.tar.gz
   fi
   cp $ETCD/etcd $ETCD/etcdctl common

   echo "Download kubernetes release ..."
   if [ ! -f kubernetes.tar.gz ] ; then
     curl -L https://github.com/GoogleCloudPlatform/kubernetes/releases/download/${K8S_VERSION}/kubernetes.tar.gz -o kubernetes.tar.gz
     tar xzf kubernetes.tar.gz
   fi
   pushd kubernetes/server
   tar xzf kubernetes-server-linux-amd64.tar.gz
   popd
   cp kubernetes/server/kubernetes/server/bin/kube-apiserver \
      kubernetes/server/kubernetes/server/bin/kube-controller-manager \
      kubernetes/server/kubernetes/server/bin/kube-scheduler master
   cp kubernetes/server/kubernetes/server/bin/kubelet \
      kubernetes/server/kubernetes/server/bin/kube-proxy node
   cp kubernetes/server/kubernetes/server/bin/kubectl common
   rm -rf flannel* kubernetes* etcd*

   echo "Done! Downloaded all components in ${KUBE_TEMP}"
  )
}

main
