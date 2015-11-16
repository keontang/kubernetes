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

# The script restores changes from k8s-replace.sh. This is necessary since we
# don't want to change upstream code.

KUBE_ROOT=$(dirname "${BASH_SOURCE}")/../..
source "${KUBE_ROOT}/hack/caicloud/common.sh"

# Restore 'gcr.io' images.
grep -rl "caicloudgcr/google_containers_[^\", ]*" \
     --include \*.go --include \*.json --include \*.yaml --include \*.yaml.in --include \*.yml --include Dockerfile --include \*.manifest \
     ${KUBE_ROOT}/test ${KUBE_ROOT}/examples ${KUBE_ROOT}/cluster/addons ${KUBE_ROOT}/cluster/saltbase ${KUBE_ROOT}/contrib ${KUBE_ROOT}/docs |
  xargs perl -X -i -pe 's|caicloudgcr/google_containers_|gcr.io/google_containers/|g'
grep -rl "caicloudgcr/google_samples_[^\", ]*" \
     --include \*.go --include \*.json --include \*.yaml --include \*.yaml.in --include \*.yml --include Dockerfile --include \*.manifest \
     ${KUBE_ROOT}/test ${KUBE_ROOT}/examples ${KUBE_ROOT}/cluster/addons ${KUBE_ROOT}/cluster/saltbase ${KUBE_ROOT}/contrib ${KUBE_ROOT}/docs |
  xargs perl -X -i -pe 's|caicloudgcr/google_samples_|gcr.io/google_samples/|g'

# Restore 'golang.org' packages.
perl -i -pe "s|go get github.com/tools/godep|go get golang.org/x/tools/cmd/cover github.com/tools/godep|g" \
     ${KUBE_ROOT}/build/build-image/Dockerfile

# Restore 'github.com' files.
perl -i -pe "s|${ETCD_URL}|https://github.com/coreos/etcd/releases/download/v2.0.0/etcd-v2.0.0-linux-amd64.tar.gz|g" \
     ${KUBE_ROOT}/build/build-image/Dockerfile
perl -i -pe "s|${ETCD_VERSION}|v2.0.0|g" ${KUBE_ROOT}/build/build-image/Dockerfile

# Restore supported e2e tests.
perl -i -pe 's|\QSkipUnlessProviderIs("gce", "gke", "aws", "caicloud-anchnet")\E|SkipUnlessProviderIs("gce", "gke", "aws")|g' \
     ${KUBE_ROOT}/test/e2e/kubectl.go
perl -i -pe 's|\QSkipUnlessProviderIs("gce", "gke", "aws", "caicloud-anchnet")\E|SkipUnlessProviderIs("gce", "gke", "aws")|g' \
     ${KUBE_ROOT}/test/e2e/service.go
perl -i -pe "s|baidu.com|google.com|g" ${KUBE_ROOT}/test/e2e/networking.go
