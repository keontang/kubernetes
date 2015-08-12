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

# Kubernetes team hosts a lot of images on gcr.io, which is blocked by GFW.
# The script pulls such images from gcr.io, and push to docker hub under
# our offical account (caicloud). Prerequisites for running the script:
# 1. The script must be ran on host outside of GFW, of course;
# 2. The host has logged into docker hub using caicloud account.

KUBE_ROOT=$(dirname "${BASH_SOURCE}")/../..

grep -IhEro "gcr.io/google_containers/[^\", ]*" \
     --include \*.go --include \*.json --include \*.yaml --include \*.yml --include Dockerfile --include \*.manifest \
     ${KUBE_ROOT}/test ${KUBE_ROOT}/examples ${KUBE_ROOT}/cluster/addons ${KUBE_ROOT}/contrib | sort -u |
  while read -r gcr_image ; do
    image=${gcr_image#"gcr.io/google_containers/"}
    caicloud_image="caicloud/$image"
    echo "Processing $gcr_image, image: $image"
    docker pull "$gcr_image"
    docker tag -f "$gcr_image" "$caicloud_image"
    docker push "$caicloud_image"
  done
