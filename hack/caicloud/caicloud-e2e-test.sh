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

# Add skipped test regex here. By default, we disable heavy tests.
CAICLOUD_TEST_SKIP_REGEX=${CAICLOUD_TEST_SKIP_REGEX:-"\[Slow\]|\[Serial\]|\[Flaky\]|\[Feature:.+\]"}

# Disable logging and monitoring since it takes a long time to bring up (due
# to docker pull image).
export ENABLE_CLUSTER_LOGGING=false
export ENABLE_CLUSTER_MONITORING=false
export ENABLE_CLUSTER_UI=false
export ENABLE_CLUSTER_REGISTRY=false

# Some e2e tests will create resources from files, we need to make sure to
# replace gcr images as well. This might not work?
${KUBE_ROOT}/hack/caicloud/k8s-replace.sh
trap-add '${KUBE_ROOT}/hack/caicloud/k8s-restore.sh' EXIT
go run "$(dirname $0)/../e2e.go" -v -build -up -test --test_args="--ginkgo.skip=${CAICLOUD_TEST_SKIP_REGEX}"

exit $?

# Note, to run a dedicated test, use --test_args="--ginkgo.focus=*", for example:
#   go run "$(dirname $0)/../e2e.go" -v -build -up -test --test_args="--ginkgo.focus=Guestbook.*working application" -down
