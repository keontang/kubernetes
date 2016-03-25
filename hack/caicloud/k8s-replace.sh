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

# The script fixes a couple of hiccups for developing kubernetes behind GFW.
# This is necessary since we don't want to change upstream code.

KUBE_ROOT=$(dirname "${BASH_SOURCE}")/../..
source "${KUBE_ROOT}/hack/caicloud/common.sh"

# 'gcr.io' is blocked - replace all gcr.io images to index.caicloud.io/caicloudgcr.
grep -rl "gcr.io/google_containers/[^\", ]*" \
     --include \*.go \
     --include \*.json \
     --include \*.yaml \
     --include \*.yaml.in \
     --include \*.yml \
     --include Dockerfile \
     --include \*.manifest \
     ${KUBE_ROOT}/test \
     ${KUBE_ROOT}/examples \
     ${KUBE_ROOT}/cluster/addons \
     ${KUBE_ROOT}/cluster/saltbase \
     ${KUBE_ROOT}/contrib \
     ${KUBE_ROOT}/docs \
     ${KUBE_ROOT}/build \
     ${KUBE_ROOT}/test/e2e/testing-manifests |
  xargs perl -X -i -pe 's|gcr.io/google_containers/|index.caicloud.io/caicloudgcr/google_containers_|g'

grep -rl "gcr.io/google_samples/[^\", ]*" \
     --include \*.go \
     --include \*.json \
     --include \*.yaml \
     --include \*.yaml.in \
     --include \*.yml \
     --include Dockerfile \
     --include \*.manifest \
     ${KUBE_ROOT}/test \
     ${KUBE_ROOT}/examples \
     ${KUBE_ROOT}/cluster/addons \
     ${KUBE_ROOT}/cluster/saltbase \
     ${KUBE_ROOT}/contrib \
     ${KUBE_ROOT}/docs \
     ${KUBE_ROOT}/build \
     ${KUBE_ROOT}/test/e2e/testing-manifests |
  xargs perl -X -i -pe 's|gcr.io/google_samples/|index.caicloud.io/caicloudgcr/google_samples_|g'

perl -i -pe "s|google.com|baidu.com|g" ${KUBE_ROOT}/test/e2e/networking.go ${KUBE_ROOT}/test/e2e/dns.go

# Conversion rule:
#   gcr.io/google_containers/es-kibana -> index.caicloud.io/caicloudgcr/google_containers_es-kibana
#   gcr.io/google_samples/frontend     -> index.caicloud.io/caicloudgcr/google_samples_frontend
