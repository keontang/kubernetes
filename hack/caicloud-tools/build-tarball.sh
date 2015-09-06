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

# The script builds tarball containing caicloud kubernetes binaries and
# other binaries (etcd, flannel). After building the tarball, we should
# upload it to internal-get.caicloud.io or qiniu.com.

# The tarball version.
CAICLOUD_VERSION="2015-09-01"

# Binary version
FLANNEL_VERSION=${FLANNEL_VERSION:-0.5.3}
ETCD_VERSION=${ETCD_VERSION:-v2.1.2}

# Build kube server binaries from current code base.
KUBE_ROOT=$(dirname "${BASH_SOURCE}")/../..
cd ${KUBE_ROOT}

hack/caicloud-tools/k8s-replace.sh
trap '${KUBE_ROOT}/hack/caicloud-tools/k8s-restore.sh' EXIT
build/run.sh hack/build-go.sh
if [[ "$?" != "0" ]]; then
  echo "Error building server binaries"
  exit 1
fi

# Fetch non-kube binaries.
wget http://internal-get.caicloud.io/etcd/etcd-$ETCD_VERSION-linux-amd64.tar.gz -O etcd-linux.tar.gz
mkdir -p etcd-linux && tar xzf etcd-linux.tar.gz -C etcd-linux --strip-components=1
wget http://internal-get.caicloud.io/flannel/flannel-$FLANNEL_VERSION-linux-amd64.tar.gz -O flannel-linux.tar.gz
mkdir -p flannel-linux && tar xzf flannel-linux.tar.gz -C flannel-linux --strip-components=1

# Make tarball 'caicloud-kube-$CAICLOUD_VERSION.tar.gz'.
mkdir caicloud-kube
cp etcd-linux/etcd etcd-linux/etcdctl flannel-linux/flanneld \
   _output/dockerized/bin/linux/amd64/kube-apiserver \
   _output/dockerized/bin/linux/amd64/kube-controller-manager \
   _output/dockerized/bin/linux/amd64/kube-proxy \
   _output/dockerized/bin/linux/amd64/kube-scheduler \
   _output/dockerized/bin/linux/amd64/kubectl \
   _output/dockerized/bin/linux/amd64/kubelet \
   caicloud-kube
tar cvzf caicloud-kube-$CAICLOUD_VERSION.tar.gz caicloud-kube
rm -rf etcd-linux.tar.gz flannel-linux.tar.gz etcd-linux flannel-linux caicloud-kube

# Make tarball 'caicloud-kube-executor-$CAICLOUD_VERSION.tar.gz'.
mkdir -p caicloud-kube-executor
cp -R hack cluster build caicloud-kube-executor
# Preserve kubectl path since kubectl.sh assumes some locations.
mkdir -p caicloud-kube-executor/_output/dockerized/bin/linux/amd64/
cp _output/dockerized/bin/linux/amd64/kubectl caicloud-kube-executor/_output/dockerized/bin/linux/amd64/
tar cvzf caicloud-kube-executor-$CAICLOUD_VERSION.tar.gz caicloud-kube-executor
rm -rf caicloud-kube-executor

cd -
