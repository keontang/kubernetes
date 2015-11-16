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

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

# Join all args with |
#   Example: join_regex_allow_empty a b "c d" e  =>  a|b|c d|e
function join_regex_allow_empty() {
  local IFS="|"
  echo "$*"
}

# Join all args with |, but in case of empty result prints "EMPTY\sSET" instead.
# This is used in ginkgo.focus flag so that we won't have empty string which matches
# all of the test cases.
#   Example: join_regex_no_empty a b "c d" e  =>  a|b|c d|e
#            join_regex_no_empty => EMPTY\sSET
function join_regex_no_empty() {
	local IFS="|"
	if [ -z "$*" ]; then
	  echo "EMPTY\sSET"
	else
	  echo "$*"
	fi
}

echo "--------------------------------------------------------------------------------"
echo "Initial Environment:"
printenv | sort
echo "--------------------------------------------------------------------------------"

# Make sure we have HOME set to WORKSPACE
export HOME=${WORKSPACE}
export GOPATH=$WORKSPACE
export PATH=$HOME/bin:$PATH

# Build tarball from k8s source
export BUILD_TARBALL="true"

# Disable logging and kube-ui
export ENABLE_CLUSTER_LOGGING=false
export ENABLE_CLUSTER_UI=false

# E2E control vars
E2E_UP=${E2E_UP:-true}
E2E_TEST=${E2E_TEST:-true}
E2E_DOWN=${E2E_DOWN:-true}

# Make sure we have ssh-agent up and running with identity added
# TODO: terminate ssh-agent when exiting?
if [[ -z ${SSH_AUTH_SOCK-} || -z `pgrep ssh-agent` ]]; then
  eval `ssh-agent -s`
fi

if [[ ! -f $HOME/.ssh/id_rsa ]]; then
  echo "+++++ No identity files found, creating... +++++"
  ssh-keygen -f ~/.ssh/id_rsa -t rsa -N ''
fi
ssh-add ~/.ssh/id_rsa

# e2e tests we don't run by default
CAICLOUD_DEFAULT_SKIP_TESTS=(
  "Skipped"
)

# e2e tests we run for each github PR
CAICLOUD_PR_TESTS=(
  "create\sa\sfunctioning\sexternal\sload\sbalancer"
)

GINKGO_TEST_ARGS="--ginkgo.skip=$(join_regex_allow_empty \
          ${CAICLOUD_DEFAULT_SKIP_TESTS[@]:+${CAICLOUD_DEFAULT_SKIP_TESTS[@]}} \
          ) --ginkgo.focus=$(join_regex_no_empty \
          ${CAICLOUD_PR_TESTS[@]:+${CAICLOUD_PR_TESTS[@]}} \
          )"

### Set up ###
if [[ "${E2E_UP}" == "true" ]]; then
  go run ./hack/e2e.go -v -build --up
fi

### Run tests ###
if [[ "${E2E_TEST}" == "true" ]]; then
  go run ./hack/e2e.go -v --test --test_args="${GINKGO_TEST_ARGS}"
fi

### Tear down
if [[ "${E2E_DOWN}" == "true" ]]; then
  go run ./hack/e2e.go -v --down
fi

# Provided for backwards compatibility, see ${KUBE_ROOT}/hack/e2e-test.sh.
# go run "$(dirname $0)/../e2e.go" -v -build -up -test --test_args="${GINKGO_TEST_ARGS}" --down

# To run a dedicated test, use --test_args="--ginkgo.focus=*", for example:
# go run "$(dirname $0)/../e2e.go" -v -build -up -test --test_args="--ginkgo.focus=Guestbook.*working application" -down

exit $?
