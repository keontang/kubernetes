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

KUBE_ROOT=$(dirname "${BASH_SOURCE}")/../..

# -----------------------------------------------------------------------------
# Parameters for building tarball.
# -----------------------------------------------------------------------------
# Do we want to upload the release to qiniu: Y or N. Default to N.
UPLOAD_TO_QINIU=${UPLOAD_TO_QINIU:-"N"}

# Do we want to upload the release to toolserver for dev: Y or N. Default to Y.
UPLOAD_TO_TOOLSERVER=${UPLOAD_TO_TOOLSERVER:-"Y"}

# Instance user and password if we want to upload to toolserver
INSTANCE_USER=${INSTANCE_USER:-"ubuntu"}
KUBE_INSTANCE_PASSWORD=${KUBE_INSTANCE_PASSWORD:-"caicloud2015ABC"}

# Use caicloud-version.sh to set release version.
source "${KUBE_ROOT}/hack/caicloud-tools/caicloud-version.sh"

# -----------------------------------------------------------------------------
# Start building tarball from current code base.
# -----------------------------------------------------------------------------
cd ${KUBE_ROOT}

# Work around mainland network connection.
hack/caicloud-tools/k8s-replace.sh
trap '${KUBE_ROOT}/hack/caicloud-tools/k8s-restore.sh' EXIT
build/run.sh hack/build-go.sh
if [[ "$?" != "0" ]]; then
  echo "Error building server binaries"
  exit 1
fi

echo "Building tarball ${CAICLOUD_KUBE_PKG} and ${CAICLOUD_KUBE_EXECUTOR_PKG}"
# Fetch non-kube binaries.
wget ${ETCD_URL} -O etcd-linux.tar.gz
mkdir -p etcd-linux && tar xzf etcd-linux.tar.gz -C etcd-linux --strip-components=1
wget ${FLANNEL_URL} -O flannel-linux.tar.gz
mkdir -p flannel-linux && tar xzf flannel-linux.tar.gz -C flannel-linux --strip-components=1

# Reset output directory.
rm -rf ${KUBE_ROOT}/_output/caicloud
mkdir -p ${KUBE_ROOT}/_output/caicloud

# Make tarball '${CAICLOUD_UPLOAD_VERSION}'.
mkdir -p caicloud-kube
cp etcd-linux/etcd etcd-linux/etcdctl flannel-linux/flanneld \
   _output/dockerized/bin/linux/amd64/kube-apiserver \
   _output/dockerized/bin/linux/amd64/kube-controller-manager \
   _output/dockerized/bin/linux/amd64/kube-proxy \
   _output/dockerized/bin/linux/amd64/kube-scheduler \
   _output/dockerized/bin/linux/amd64/kubectl \
   _output/dockerized/bin/linux/amd64/kubelet \
   caicloud-kube
tar cvzf ${KUBE_ROOT}/_output/caicloud/${CAICLOUD_KUBE_PKG} caicloud-kube
rm -rf etcd-linux.tar.gz flannel-linux.tar.gz etcd-linux flannel-linux caicloud-kube

# Make tarball '${EXECUTOR_UPLOAD_VERSION}'.
mkdir -p caicloud-kube-executor
cp -R hack cluster build caicloud-kube-executor
# Preserve kubectl path since kubectl.sh assumes some locations.
mkdir -p caicloud-kube-executor/_output/dockerized/bin/linux/amd64/
cp _output/dockerized/bin/linux/amd64/kubectl caicloud-kube-executor/_output/dockerized/bin/linux/amd64/
tar cvzf ${KUBE_ROOT}/_output/caicloud/${CAICLOUD_KUBE_EXECUTOR_PKG} caicloud-kube-executor
rm -rf caicloud-kube-executor

cd -

# Decide if we upload releases to Toolserver.
if [[ "${UPLOAD_TO_TOOLSERVER}" == "Y" ]]; then
  expect <<EOF
set timeout -1
spawn scp -r -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
  ${KUBE_ROOT}/_output/caicloud "${INSTANCE_USER}@internal-get.caicloud.io:~"
expect {
  "*?assword*" {
    send -- "${KUBE_INSTANCE_PASSWORD}\r"
    exp_continue
  }
  eof {}
}
EOF

  expect <<EOF
set timeout -1
spawn ssh -t -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
  ${INSTANCE_USER}@internal-get.caicloud.io "sudo mv caicloud/* /data/www/static/caicloud"
expect {
  "*?assword*" {
    send -- "${KUBE_INSTANCE_PASSWORD}\r"
    exp_continue
  }
  eof {}
}
EOF
fi

# Decide if we upload releases to Qiniu.
if [[ "${UPLOAD_TO_QINIU}" == "Y" ]]; then
  if [[ "$(which qrsync)" == "" ]]; then
    echo "Can't find qrsync cli binary in PATH - unable to upload to Qiniu."
    exit 1
  fi
  # Change directory to qiniu-conf.json: Qiniu SDK has assumptions about path.
  cd ${KUBE_ROOT}/hack/caicloud-tools
  qrsync qiniu-conf.json
  cd -
fi
