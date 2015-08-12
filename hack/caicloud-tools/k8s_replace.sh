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

KUBE_ROOT=$(dirname "${BASH_SOURCE}")/../..

# The script fixes a couple of hiccups for developing kubernetes behind GFW.

# 'gcr.io' is blocked - replace all gcr.io images to ones we uploaded to docker
# hub caicloud account.
grep -rl "gcr.io/google_containers/[^\", ]*" \
     --include \*.go --include \*.json --include \*.yaml --include \*.yml --include Dockerfile --include \*.manifest \
     ${KUBE_ROOT}/test ${KUBE_ROOT}/examples ${KUBE_ROOT}/cluster/addons ${KUBE_ROOT}/contrib |
  xargs sed -i "" 's|gcr.io/google_containers/|caicloud/|g'


# 'golang.org' is blocked - remove it since we do not need it for building.
sed -i "" "s|go get golang.org/x/tools/cmd/cover github.com/tools/godep|go get github.com/tools/godep|g" \
    ${KUBE_ROOT}/build/build-image/Dockerfile


# Accessing 'github.com' is slow, replace it with our own file server
sed -i "" "s|https://github.com/coreos/etcd/releases/download/v2.0.0/etcd-v2.0.0-linux-amd64.tar.gz|http://deyuan.me:9999/etcd-v2.0.0-linux-amd64.tar.gz|g" \
    ${KUBE_ROOT}/build/build-image/Dockerfile
