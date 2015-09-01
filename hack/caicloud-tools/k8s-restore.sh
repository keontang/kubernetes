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

# The script restores changes from k8s-replace.sh. This is necessary since we
# don't want to change upstream code.

# Restore 'gcr.io' images.
grep -rl "caicloudgcr/[^\", ]*" \
     --include \*.go --include \*.json --include \*.yaml --include \*.yaml.in --include \*.yml --include Dockerfile --include \*.manifest \
     ${KUBE_ROOT}/test ${KUBE_ROOT}/examples ${KUBE_ROOT}/cluster/addons ${KUBE_ROOT}/contrib |
  xargs sed -i "" 's|caicloudgcr/|gcr.io/google_containers/|g'

# Restore 'golang.org' packages.
sed -i "" "s|go get github.com/tools/godep|go get golang.org/x/tools/cmd/cover github.com/tools/godep|g" \
    ${KUBE_ROOT}/build/build-image/Dockerfile

# Restore 'github.com' files.
sed -i "" "s|http://internal-get.caicloud.io/etcd/etcd-v2.0.0-linux-amd64.tar.gz|\
https://github.com/coreos/etcd/releases/download/v2.0.0/etcd-v2.0.0-linux-amd64.tar.gz|g" \
    ${KUBE_ROOT}/build/build-image/Dockerfile

# Restore supported e2e tests.
sed -i "" "s|SkipUnlessProviderIs(\"gce\", \"gke\", \"aws\", \"anchnet\")|SkipUnlessProviderIs(\"gce\", \"gke\", \"aws\")|g" \
    ${KUBE_ROOT}/test/e2e/kubectl.go
sed -i "" "s|SkipUnlessProviderIs(\"gce\", \"gke\", \"aws\", \"anchnet\")|SkipUnlessProviderIs(\"gce\", \"gke\", \"aws\")|g" \
    ${KUBE_ROOT}/test/e2e/service.go
sed -i "" "s|baidu.com|google.com|g" ${KUBE_ROOT}/test/e2e/networking.go
