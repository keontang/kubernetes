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

# The script fixes a couple of hiccups for developing kubernetes behind GFW.

KUBE_ROOT=$(dirname "${BASH_SOURCE}")/../..
source "${KUBE_ROOT}/hack/caicloud-tools/caicloud-version.sh"

# 'gcr.io' is blocked - replace all gcr.io images to ones we uploaded to docker
# hub caicloudgcr account.
grep -rl "gcr.io/google_containers/[^\", ]*" \
     --include \*.go --include \*.json --include \*.yaml --include \*.yaml.in --include \*.yml --include Dockerfile --include \*.manifest \
     ${KUBE_ROOT}/test ${KUBE_ROOT}/examples ${KUBE_ROOT}/cluster/addons ${KUBE_ROOT}/contrib ${KUBE_ROOT}/docs |
  xargs perl -X -i -pe 's|gcr.io/google_containers/|caicloudgcr/|g'

# 'golang.org' is blocked - remove it since we do not need it for building.
perl -i -pe "s|go get golang.org/x/tools/cmd/cover github.com/tools/godep|go get github.com/tools/godep|g" \
     ${KUBE_ROOT}/build/build-image/Dockerfile

# Accessing 'github.com' is slow, replace it with our hosted files.
perl -i -pe "s|https://github.com/coreos/etcd/releases/download/v2.0.0/etcd-v2.0.0-linux-amd64.tar.gz|${ETCD_URL}|g" \
     ${KUBE_ROOT}/build/build-image/Dockerfile
perl -i -pe "s|v2.0.0|${ETCD_VERSION}|g" ${KUBE_ROOT}/build/build-image/Dockerfile

# Our cloudprovider supports following e2e tests.
perl -i -pe 's|\QSkipUnlessProviderIs("gce", "gke", "aws")\E|SkipUnlessProviderIs("gce", "gke", "aws", "anchnet")|g' \
     ${KUBE_ROOT}/test/e2e/kubectl.go
perl -i -pe 's|\QSkipUnlessProviderIs("gce", "gke", "aws")\E|SkipUnlessProviderIs("gce", "gke", "aws", "anchnet")|g' \
     ${KUBE_ROOT}/test/e2e/service.go
perl -i -pe "s|google.com|baidu.com|g" ${KUBE_ROOT}/test/e2e/networking.go
