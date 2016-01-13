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

# Kubernetes team hosts a lot of images on gcr.io, which is blocked by GFW.
# The script pulls such images from gcr.io, and push to index.caicloud.io
# The script must be ran on host outside of GFW.

KUBE_ROOT=$(dirname "${BASH_SOURCE}")/../..

# Sync a single image. $1 will be pulled, then tagged and pushed as $2.
#
# Input:
#   $1 The image to pull
#   $2 The image to push
function sync_image {
  docker pull "$1"
  docker tag -f "$1" "$2"
  docker push "$2"
}

# Sync images in gcr.io/google_containers. E.g.
#     gcr.io/google_containers/cloudsql-authenticator
#  -> index.caicloud.io/caicloudgcr/google_containers_cloudsql-authenticator
grep -IhEro "gcr.io/google_containers/[^\", ]*" \
     --include \*.go --include \*.json --include \*.yaml --include \*.yaml.in --include \*.yml --include Dockerfile --include \*.manifest \
     ${KUBE_ROOT}/test ${KUBE_ROOT}/examples ${KUBE_ROOT}/cluster/addons ${KUBE_ROOT}/cluster/saltbase ${KUBE_ROOT}/contrib ${KUBE_ROOT}/docs | sort -u |
  while read -r gcr_image ; do
    image=${gcr_image#"gcr.io/google_containers/"}
    caicloud_image="index.caicloud.io/caicloudgcr/google_containers_$image"
    echo "++++++++++ Processing $gcr_image, image: $image"
    sync_image "$gcr_image" "$caicloud_image"
  done

# Sync images in gcr.io/google_samples.
#     gcr.io/google_samples/gb-frontend:v3
#  -> index.caicloud.io/caicloudgcr/google_samples_gb-frontend:v3
grep -IhEro "gcr.io/google_samples/[^\", ]*" \
     --include \*.go --include \*.json --include \*.yaml --include \*.yaml.in --include \*.yml --include Dockerfile --include \*.manifest \
     ${KUBE_ROOT}/test ${KUBE_ROOT}/examples ${KUBE_ROOT}/cluster/addons ${KUBE_ROOT}/cluster/saltbase ${KUBE_ROOT}/contrib ${KUBE_ROOT}/docs | sort -u |
  while read -r gcr_image ; do
    image=${gcr_image#"gcr.io/google_samples/"}
    caicloud_image="index.caicloud.io/caicloudgcr/google_samples_$image"
    echo "++++++++++ Processing $gcr_image, image: $image"
    sync_image "$gcr_image" "$caicloud_image"
  done
