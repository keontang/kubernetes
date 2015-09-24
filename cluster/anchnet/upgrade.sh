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

# Upgrade anchnet cluster to a new release version.

set -o errexit
set -o nounset
set -o pipefail

KUBE_ROOT=$(dirname "${BASH_SOURCE}")/../..
source ${KUBE_ROOT}/cluster/anchnet/util.sh


function usage {
  echo -e "Usage:"
  echo -e "  ./upgrade.sh [version]"
  echo -e ""
  echo -e "Parameter:"
  echo -e " version\tTarball release version. If provided, the tag must be the form of vA.B.C."
  echo -e ""
  echo -e "Environment variable:"
}
