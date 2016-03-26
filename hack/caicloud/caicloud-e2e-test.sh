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

# For how kubernetes structures e2e test, see:
#   https://github.com/kubernetes/kubernetes/blob/master/docs/devel/e2e-tests.md
# Especially:
#   https://github.com/kubernetes/kubernetes/blob/master/docs/devel/e2e-tests.md#kinds-of-tests

# Add focused test regex here. If this is not empty, we'll only run focused tests.
# Note:
#  - We don't call build and up for focused tests: build is needed if any
#    e2e related files have changed; up is needed to bring up a new cluster.
#  - To match "kubectl run default", you must supply "kubectl.*run.*default"
CAICLOUD_TEST_FOCUS_REGEX=${CAICLOUD_TEST_FOCUS_REGEX:-""}

# Add skipped test regex here. Ignored CAICLOUD_TEST_FOCUS_REGEX is not empty. By
# default, heavy tests are disabled.
CAICLOUD_TEST_SKIP_REGEX=${CAICLOUD_TEST_SKIP_REGEX:-"\[Slow\]|\[Serial\]|\[Flaky\]|\[Disruptive\]|\[Feature:.+\]"}

# By default, do not run unit/integration tests.
export KUBE_RELEASE_RUN_TESTS=${KUBE_RELEASE_RUN_TESTS:-"N"}

# Disable logging and monitoring since it takes a long time to bring up (due
# to docker pull image).
export ENABLE_CLUSTER_LOGGING=false
export ENABLE_CLUSTER_MONITORING=false
export ENABLE_CLUSTER_REGISTRY=false
# Enable cluster dashboard.
export ENABLE_CLUSTER_DASHBOARD=true

if [[ "${CAICLOUD_TEST_FOCUS_REGEX}" = "" ]]; then
  # Build code base, create new cluster and run all tests. Do not check version skew
  # since server & client version may slightly differ in caicloud.
  go run "$(dirname $0)/../e2e.go" -v -build -up -test --check_version_skew=false --test_args="--ginkgo.skip=${CAICLOUD_TEST_SKIP_REGEX}"
else
  go run "$(dirname $0)/../e2e.go" -v -test --check_version_skew=false --test_args="--ginkgo.focus=${CAICLOUD_TEST_FOCUS_REGEX}"
fi

exit $?
