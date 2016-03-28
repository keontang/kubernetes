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
#   - To match "kubectl run default", you must supply "kubectl.*run.*default"
#   - CAICLOUD_TEST_FOCUS_REGEX take precedence over CAICLOUD_TEST_SKIP_REGEX
CAICLOUD_TEST_FOCUS_REGEX=${CAICLOUD_TEST_FOCUS_REGEX:-""}

# Add skipped test regex here. Ignored CAICLOUD_TEST_FOCUS_REGEX is not empty. By
# default, heavy tests are disabled.
CAICLOUD_TEST_SKIP_REGEX=${CAICLOUD_TEST_SKIP_REGEX:-"\[Slow\]|\[Serial\]|\[Flaky\]|\[Disruptive\]|\[Feature:.+\]"}

# Build and up is not desired if we want to run some focused tests.
BUILD_AND_UP=${BUILD_AND_UP:-"Y"}

# By default, do not run unit/integration tests.
KUBE_RELEASE_RUN_TESTS=${KUBE_RELEASE_RUN_TESTS:-"N"}

# Addon switches.
export ENABLE_CLUSTER_DASHBOARD=true
export ENABLE_CLUSTER_MONITORING=true
export ENABLE_CLUSTER_LOGGING=false
export ENABLE_CLUSTER_REGISTRY=false

# Do not check version skew since server & client version may slightly differ in caicloud.
if [[ "${BUILD_AND_UP}" == "Y" ]]; then
  OPTS="-build -up -v -test --check_version_skew=false"
else
  OPTS="-v -test --check_version_skew=false"
fi

if [[ "${CAICLOUD_TEST_FOCUS_REGEX}" = "" ]]; then
  go run "$(dirname $0)/../e2e.go" ${OPTS} --test_args="--ginkgo.skip=${CAICLOUD_TEST_SKIP_REGEX}"
else
  go run "$(dirname $0)/../e2e.go" ${OPTS} --test_args="--ginkgo.focus=${CAICLOUD_TEST_FOCUS_REGEX}"
fi

exit $?
