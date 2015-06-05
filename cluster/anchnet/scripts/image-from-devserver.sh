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

# The script makes current instance a usable base image. It build current
# codebase and put them into ~/kube. It must be run inside development
# server in anchnet.

set -e

ETCD_VERSION="v2.0.12"
FLANNEL_VERSION="0.4.0"
DOCKER_VERSION="1.7.0"          # Usually installed manually


KUBE_ROOT=$(dirname "${BASH_SOURCE}")/../../..
source "${KUBE_ROOT}/hack/build-go.sh"


function InstallPackages {
  sudo apt-get install lxc-docker-${DOCKER_VERSION}
  sudo apt-get install bridge-utils
}


function InstallBinaries {
  mkdir -p ~/staging/etcd
  mkdir -p ~/staging/flannel
  mkdir -p ~/kube/master ~/kube/node

  (
    cd ~/staging/flannel
    FLANNEL_PACKAGE="flannel-${FLANNEL_VERSION}-linux-amd64.tar.gz"
    FLANNEL_DIR="flannel-${FLANNEL_VERSION}"
    if [[ ! -e ${FLANNEL_PACKAGE} ]]; then
      wget https://github.com/coreos/flannel/releases/download/v${FLANNEL_VERSION}/${FLANNEL_PACKAGE}
      tar xzf ${FLANNEL_PACKAGE}
    fi
    cp $FLANNEL_DIR/flanneld ~/kube/master
    cp $FLANNEL_DIR/flanneld ~/kube/node
  )

  (
    cd ~/staging/etcd
    ETCD_PACKAGE="etcd-${ETCD_VERSION}-linux-amd64.tar.gz"
    ETCD_DIR="etcd-${ETCD_VERSION}-linux-amd64"
    if [[ ! -e ${ETCD_PACKAGE} ]]; then
      wget https://github.com/coreos/etcd/releases/download/${ETCD_VERSION}/${ETCD_PACKAGE}
      tar xzf ${ETCD_PACKAGE}
    fi
    cp $ETCD_DIR/etcd $ETCD_DIR/etcdctl ~/kube/master
    cp $ETCD_DIR/etcd $ETCD_DIR/etcdctl ~/kube/node
  )

  cp ${KUBE_ROOT}/_output/local/bin/linux/amd64/kube-controller-manager \
     ${KUBE_ROOT}/_output/local/bin/linux/amd64/kube-apiserver \
     ${KUBE_ROOT}/_output/local/bin/linux/amd64/kube-scheduler \
     ${KUBE_ROOT}/_output/local/bin/linux/amd64/kubectl \
     ~/kube/master
  cp ${KUBE_ROOT}/_output/local/bin/linux/amd64/kubelet \
     ${KUBE_ROOT}/_output/local/bin/linux/amd64/kube-proxy \
     ${KUBE_ROOT}/_output/local/bin/linux/amd64/kubectl \
     ~/kube/node

  echo "Binaries copied. Please stop the instance and build image."
}


InstallBinaries
