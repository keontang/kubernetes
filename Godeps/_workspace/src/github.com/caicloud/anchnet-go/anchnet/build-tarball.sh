#!/bin/bash

# Copyright 2015 anchnet-go authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# The script cross builds tarball release, see usage function for how to
# run the script. After building completes, anchnet gosdk tarball will be
# created, i.e.:
#   _output/anchnet-go-linux-amd64-$VERSION.tar.gz
#   _output/anchnet-go-darwin-amd64-$VERSION.tar.gz
# Tarball content:
#   `-- anchnet: Anchnet binary

set -o errexit
set -o nounset
set -o pipefail

function usage {
  echo -e "Usage:"
  echo -e "  ./build-tarball.sh vesion"
  echo -e ""
  echo -e "Parameter:"
  echo -e " version\tTarball release version, must in the form of vA.B.C, where A, B, C are digits, e.g. v1.0.1"
  echo -e ""
  echo -e "Environment variable:"
  echo -e " UPLOAD_TO_QINIU\tSet to Y if the script needs to push new tarballs to qiniu, default value: ${UPLOAD_TO_QINIU}"
  echo -e " UPLOAD_TO_TOOLSERVER\tSet to Y if the script needs to push new tarballs to toolserver, default value: ${UPLOAD_TO_TOOLSERVER}"
  echo -e " BUILD_GOLANG_TAG\tThe golang image tag used to cross build binaries, default value: ${BUILD_GOLANG_TAG}"
}

# -----------------------------------------------------------------------------
# Parameters for building tarball.
# -----------------------------------------------------------------------------
# Do we want to upload the release to qiniu: Y or N. Default to N.
UPLOAD_TO_QINIU=${UPLOAD_TO_QINIU:-"N"}

# Do we want to upload the release to toolserver for dev: Y or N. Default to Y.
UPLOAD_TO_TOOLSERVER=${UPLOAD_TO_TOOLSERVER:-"Y"}

# Image tag for golang cross build.
BUILD_GOLANG_TAG="1.4-cross"

# Instance user and password if we want to upload to toolserver.
INSTANCE_USER=${INSTANCE_USER:-"ubuntu"}
KUBE_INSTANCE_PASSWORD=${KUBE_INSTANCE_PASSWORD:-"caicloud2015ABC"}

if [[ "$#" != "1" ]]; then
  echo -e "Error: Version must be provided."
  echo -e ""
  usage
  exit 1
fi
if [[ ! $1 =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo -e "Error: Version format error, see usage."
  echo -e ""
  usage
  exit 1
fi

# Version of current build, must be provided by caller. Version format is
# validated above.
VERSION=${1}

# DO NOT CHANGE. Derived variables for tarball building.
SDK_LINUX_DIR="anchnet-go-linux-amd64-$VERSION"
SDK_DARWIN_DIR="anchnet-go-darwin-amd64-$VERSION"
SDK_LINUX_PACKAGE="anchnet-go-linux-amd64-$VERSION.tar.gz"
SDK_DARWIN_PACKAGE="anchnet-go-darwin-amd64-$VERSION.tar.gz"

# -----------------------------------------------------------------------------
# Start Building tarball.
# -----------------------------------------------------------------------------
ROOT=$(dirname "${BASH_SOURCE}")/..
cd ${ROOT}

# Cross build tarball and move it to ${ROOT}/_output directory.
if [[ `uname` == "Darwin" ]]; then
  boot2docker start > /dev/null 2>&1
  eval "$(boot2docker shellinit)" > /dev/null 2>&1
fi

# Clean output directory.
rm -rf _output && mkdir -p _output

# Build linux tarball.
docker run --rm \
       -v "$PWD":/go/src/github.com/caicloud/anchnet-go \
       -w /go/src/github.com/caicloud/anchnet-go/anchnet \
       -e GOOS=linux \
       -e GOARCH=amd64 \
       -e GOPATH=/go/src/github.com/caicloud/anchnet-go/Godeps/_workspace:/go \
       golang:$BUILD_GOLANG_TAG go build -v
mkdir -p ${SDK_LINUX_DIR} && mv anchnet/anchnet ${SDK_LINUX_DIR}
tar cvzf ${SDK_LINUX_PACKAGE} ${SDK_LINUX_DIR} && mv ${SDK_LINUX_PACKAGE} _output
rm -rf anchnet/anchnet ${SDK_LINUX_DIR}

# Build Darwin tarball.
docker run --rm \
       -v "$PWD":/go/src/github.com/caicloud/anchnet-go \
       -w /go/src/github.com/caicloud/anchnet-go/anchnet \
       -e GOOS=darwin \
       -e GOARCH=amd64 \
       -e GOPATH=/go/src/github.com/caicloud/anchnet-go/Godeps/_workspace:/go \
       golang:$BUILD_GOLANG_TAG go build -v
mkdir -p ${SDK_DARWIN_DIR} && mv anchnet/anchnet ${SDK_DARWIN_DIR}
tar cvzf ${SDK_DARWIN_PACKAGE} ${SDK_DARWIN_DIR} && mv ${SDK_DARWIN_PACKAGE} _output
rm -rf anchnet/anchnet ${SDK_DARWIN_DIR}

cd -

# Decide if we need to upload the releases to toolserver.
if [[ "${UPLOAD_TO_TOOLSERVER}" == "Y" ]]; then
  expect <<EOF
set timeout -1
spawn scp -r -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
  ${ROOT}/_output/${SDK_LINUX_PACKAGE} ${ROOT}/_output/${SDK_DARWIN_PACKAGE} "${INSTANCE_USER}@get.bitintuitive.com:~"
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
  ${INSTANCE_USER}@get.bitintuitive.com "\
sudo mv ${SDK_LINUX_PACKAGE} /data/www/static/caicloud && \
sudo mv ${SDK_DARWIN_PACKAGE} /data/www/static/caicloud"
expect {
  "*?assword*" {
    send -- "${KUBE_INSTANCE_PASSWORD}\r"
    exp_continue
  }
  eof {}
}
EOF
fi

# Decide if we need to upload the releases to Qiniu.
if [[ "${UPLOAD_TO_QINIU}" == "Y" ]]; then
  if [[ "$(which qrsync)" == "" ]]; then
    echo "Can't find qrsync cli binary in PATH - unable to upload to Qiniu."
    exit 1
  fi
  # Change directory to qiniu-conf.json: Qiniu SDK has assumptions about path.
  cd ${ROOT}/anchnet
  qrsync qiniu-conf.json
  cd -
fi
