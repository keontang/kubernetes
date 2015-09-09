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

# The script defines caicloud specific parameters used across all cloud
# providers, releasees, etc. Before running any of our scripts, source
# the file to get caicloud environment.

# Caicloud release version and url, used for:
#   1. Fetching release in tarball mode
CAICLOUD_DOWNLOAD_VERSION="caicloud-kube-2015-09-09-001.tar.gz"
CAICLOUD_TARBALL_URL=${CAICLOUD_TARBALL_URL:-"http://internal-get.caicloud.io/caicloud/${CAICLOUD_DOWNLOAD_VERSION}"}

# Caicloud release version, used for:
#   1. Building release in build-tarball.sh. This is usually a newer version.
CAICLOUD_UPLOAD_VERSION="caicloud-kube-2015-09-09-001.tar.gz"

# Executor kube-up release version, used for:
#   1. Building release in build-tarball.sh, for executor.
# Note, this must keep in sync with executor build script.
EXECUTOR_UPLOAD_VERSION="caicloud-kube-executor-2015-09-09-001.tar.gz"

# Non-kube binaries versions and urls, used for:
#   1. Building release in build-tarball.sh
#   2. Fetching packages in full mode
ETCD_VERSION=${ETCD_VERSION:-v2.1.2}
FLANNEL_VERSION=${FLANNEL_VERSION:-0.5.3}
ETCD_URL="http://7xli2p.dl1.z0.glb.clouddn.com/etcd-$ETCD_VERSION-linux-amd64.tar.gz"
FLANNEL_URL="http://7xli2p.dl1.z0.glb.clouddn.com/flannel-$FLANNEL_VERSION-linux-amd64.tar.gz"

# Docker version, used for:
#   1. Installing docker in full mode
DOCKER_VERSION=${DOCKER_VERSION:-1.7.1}
