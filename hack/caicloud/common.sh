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

# Third-party binary versions, used to create tarball, etc.
ETCD_VERSION=${ETCD_VERSION:-v2.2.0}
FLANNEL_VERSION=${FLANNEL_VERSION:-0.5.3}

# URL of the server hosting packages.
RELEASE_HOST_URL="http://7xli2p.dl1.z0.glb.clouddn.com"

# Derived variables. DO NOT CHANGE.
ETCD_PACKAGE="etcd-${ETCD_VERSION}-linux-amd64.tar.gz"
FLANNEL_PACKAGE="flannel-${FLANNEL_VERSION}-linux-amd64.tar.gz"
ETCD_URL="${RELEASE_HOST_URL}/${ETCD_PACKAGE}"
FLANNEL_URL="${RELEASE_HOST_URL}/${FLANNEL_PACKAGE}"
