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

# For how kubernetes structures e2e tests, see:
#   https://github.com/kubernetes/kubernetes/blob/master/docs/devel/e2e-tests.md
# Especially:
#   https://github.com/kubernetes/kubernetes/blob/master/docs/devel/e2e-tests.md#kinds-of-tests
#
# Typical workflow for running caicloud e2e tests:
# Step1:
#   Build codebase, create a new cluster and run default set of tests (see
#   DEFAULT_TEST_SKIP_REGEX for all tests).
#   $ KUBERNETES_PROVIDER=caicloud-anchnet ./hack/caicloud/caicloud-e2e-test.sh
# Step2:
#   Test features enabled in caicloud, on the same cluster e.g.
#   $ TEST_BUILD=N TEST_UP=N CAICLOUD_TEST_FOCUS_REGEX="\[Feature:Elasticsearch\]" \
#      KUBERNETES_PROVIDER=caicloud-anchnet ./hack/caicloud/caicloud-e2e-test.sh#
# Step3:
#   R-run failure tests. You may want to create a new cluster if you touches core
#   kubernetes codebase:
#   $ TEST_BUILD=Y TEST_UP=N CAICLOUD_TEST_FOCUS_REGEX="\[ReplicationController.*light\]" \
#      KUBERNETES_PROVIDER=caicloud-anchnet ./hack/caicloud/caicloud-e2e-test.sh#
#
# Add focused test regex here. If this is not empty, we'll only run focused tests.
# Note:
#   - CAICLOUD_TEST_FOCUS_REGEX take precedence over CAICLOUD_TEST_SKIP_REGEX
#   - Match must use regular expression, e.g. to match "kubectl run default", you
#     must supply "kubectl.*run.*default"
CAICLOUD_TEST_FOCUS_REGEX=${CAICLOUD_TEST_FOCUS_REGEX:-""}

# Add skipped test regex here. Note:
#   - CAICLOUD_TEST_FOCUS_REGEX take precedence over CAICLOUD_TEST_SKIP_REGEX
#   - By default, heavy tests are disabled
#   - By default, features are all excluded. Those features are supplemental
#     features, not core kubernetes features, so skipping them is fine in most
#     cases. Use `grep -r "\[Feature.*\]"` to find all featured tests.
DEFAULT_TEST_SKIP_REGEX="\[Slow\]|\[Serial\]|\[Flaky\]|\[Disruptive\]|\[Feature:.+\]"
CAICLOUD_TEST_SKIP_REGEX=${CAICLOUD_TEST_SKIP_REGEX:-${DEFAULT_TEST_SKIP_REGEX}}

# Build and up is not desired if we want to run some focused tests.
TEST_BUILD=${TEST_BUILD:-"Y"}
TEST_UP=${TEST_UP:-"Y"}

# By default, do not run unit/integration tests.
KUBE_RELEASE_RUN_TESTS=${KUBE_RELEASE_RUN_TESTS:-"N"}

# Addon switches. Note, change values here could result in e2e test failure as
# default tests will test dashboard, monitoring and logging.
export ENABLE_CLUSTER_DASHBOARD=true
export ENABLE_CLUSTER_MONITORING=true
export ENABLE_CLUSTER_LOGGING=true
export ENABLE_CLUSTER_REGISTRY=false

# Do not check version skew since server & client version may slightly differ in caicloud.
OPTS="-v -test --check_version_skew=false"
if [[ "${TEST_BUILD}" = "Y" ]]; then
  OPTS="${OPTS} -build"
fi
if [[ "${TEST_UP}" = "Y" ]]; then
  OPTS="${OPTS} -up"
fi

if [[ "${CAICLOUD_TEST_FOCUS_REGEX}" = "" ]]; then
  go run "$(dirname $0)/../e2e.go" ${OPTS} --test_args="--ginkgo.skip=${CAICLOUD_TEST_SKIP_REGEX}"
else
  go run "$(dirname $0)/../e2e.go" ${OPTS} --test_args="--ginkgo.focus=${CAICLOUD_TEST_FOCUS_REGEX}"
fi

exit $?
