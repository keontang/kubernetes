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

# The script builds two tarballs, one containing caicloud kubernetes binaries
# and other binaries (etcd, flannel); the other one contains kube-up, kube-dwon
# scripts. After building the tarballs, we can choose to upload it to toolserver
# or qiniu.com.

set -o errexit
set -o nounset
set -o pipefail

function usage {
  echo -e "Usage:"
  echo -e "  ./build-tarball.sh [version]"
  echo -e ""
  echo -e "Parameter:"
  echo -e " version\tTarball release version. If provided, the tag must be the form of vA.B.C, where"
  echo -e "        \tA, B, C are digits, e.g. v1.0.1. If not provided, current date/time will be used,"
  echo -e "        \ti.e. YYYY-mm-DD-HH-MM-SS, where YYY is year, mm is month, DD is day, HH is hour,"
  echo -e "        \tMM is minute and SS is second, e.g. 2015-09-10-18-15-30. The second case is used"
  echo -e "        \tfor development."
  echo -e ""
  echo -e "Environment variable:"
  echo -e " UPLOAD_TO_TOOLSERVER\tSet to Y if the script needs to push new tarballs to toolserver, default to Y"
  echo -e " UPLOAD_TO_QINIU\tSet to Y if the script needs to push new tarballs to qiniu, default to N"
  echo -e " ETCD_VERSION\tetcd version to use. etcd will be packed into release tarball, default value is ${ETCD_VERSION}"
  echo -e " FLANNEL_VERSION\tflannel version to use. flannel will be packed into release tarball, default value is ${FLANNEL_VERSION}"
}

KUBE_ROOT=$(dirname "${BASH_SOURCE}")/../..

# -----------------------------------------------------------------------------
# Parameters for building tarball.
# -----------------------------------------------------------------------------
# Do we want to upload the release to qiniu: Y or N. Default to N.
UPLOAD_TO_QINIU=${UPLOAD_TO_QINIU:-"N"}

# Do we want to upload the release to toolserver for dev: Y or N. Default to Y.
UPLOAD_TO_TOOLSERVER=${UPLOAD_TO_TOOLSERVER:-"Y"}

# Instance user and password if we want to upload to toolserver.
INSTANCE_USER=${INSTANCE_USER:-"ubuntu"}
KUBE_INSTANCE_PASSWORD=${KUBE_INSTANCE_PASSWORD:-"caicloud2015ABC"}

# Get configs and commone utilities.
source ${KUBE_ROOT}/hack/caicloud/common.sh

# Find caicloud kubernetes release version.
if [[ "$#" == "1" ]]; then
  if [[ "$1" == "help" ]]; then
    echo -e ""
    usage
    exit 0
  elif [[ ! $1 =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ && ! $1 =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}$ ]]; then
    # We also allow passing date/time directly, this is usually used internally.
    echo -e "Error: Version format error, see usage."
    echo -e ""
    usage
    exit 1
  else
    CAICLOUD_VERSION=${1}
  fi
else
  CAICLOUD_VERSION="`TZ=Asia/Shanghai date +%Y-%m-%d-%H-%M-%S`"
fi

# DO NOT CHANGE. Derived variables for tarball building.
CAICLOUD_KUBE_PKG="caicloud-kube-${CAICLOUD_VERSION}.tar.gz"
CAICLOUD_KUBE_EXECUTOR_PKG="caicloud-kube-executor-${CAICLOUD_VERSION}.tar.gz"

# -----------------------------------------------------------------------------
# Start building tarball from current code base.
# -----------------------------------------------------------------------------
cd ${KUBE_ROOT}

# Work around mainland network connection.
hack/caicloud/k8s-replace.sh
trap '${KUBE_ROOT}/hack/caicloud/k8s-restore.sh' EXIT
build/run.sh hack/build-go.sh
if [[ "$?" != "0" ]]; then
  echo "Error building server binaries"
  exit 1
fi

echo "Building tarball ${CAICLOUD_KUBE_PKG} and ${CAICLOUD_KUBE_EXECUTOR_PKG}"

# Fetch non-kube binaries.
if [[ ! -f ${KUBE_ROOT}/hack/caicloud/cache/${ETCD_PACKAGE} ]]; then
  mkdir -p ${KUBE_ROOT}/hack/caicloud/cache && wget ${ETCD_URL} -P ${KUBE_ROOT}/hack/caicloud/cache
fi
mkdir -p etcd-linux && tar xzf ${KUBE_ROOT}/hack/caicloud/cache/${ETCD_PACKAGE} -C etcd-linux --strip-components=1

if [[ ! -f ${KUBE_ROOT}/hack/caicloud/cache/${FLANNEL_PACKAGE} ]]; then
  mkdir -p ${KUBE_ROOT}/hack/caicloud/cache && wget ${FLANNEL_URL} -P ${KUBE_ROOT}/hack/caicloud/cache
fi
mkdir -p flannel-linux && tar xzf ${KUBE_ROOT}/hack/caicloud/cache/${FLANNEL_PACKAGE} -C flannel-linux --strip-components=1

# Reset output directory.
rm -rf ${KUBE_ROOT}/_output/caicloud && mkdir -p ${KUBE_ROOT}/_output/caicloud

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
tar czf ${KUBE_ROOT}/_output/caicloud/${CAICLOUD_KUBE_PKG} caicloud-kube
rm -rf etcd-linux flannel-linux caicloud-kube

# Make tarball '${EXECUTOR_UPLOAD_VERSION}'.
mkdir -p caicloud-kube-executor
cp -R hack cluster build caicloud-kube-executor
# Preserve kubectl path since kubectl.sh assumes some locations.
mkdir -p caicloud-kube-executor/_output/dockerized/bin/linux/amd64/
cp _output/dockerized/bin/linux/amd64/kubectl caicloud-kube-executor/_output/dockerized/bin/linux/amd64/
tar czf ${KUBE_ROOT}/_output/caicloud/${CAICLOUD_KUBE_EXECUTOR_PKG} caicloud-kube-executor
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
  cd ${KUBE_ROOT}/hack/caicloud
  qrsync qiniu-conf.json
  cd -
fi

# A reminder for creating Github release.
if [[ "$#" == "1" && $1 =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Finish building release ${CAICLOUD_VERSION}; if this is a formal release, please remember"
  echo "to create a release tag at Github (https://github.com/caicloud/caicloud-kubernetes/releases)"
fi
