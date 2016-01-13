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

# Add skipped test regex here.
CAICLOUD_TEST_SKIP_REGEX=${CAICLOUD_TEST_SKIP_REGEX:-"Skipped|Example"}

# Disable logging and monitoring since it takes a long time to bring up (due to docker pull image).
export ENABLE_CLUSTER_LOGGING=false
export ENABLE_CLUSTER_MONITORING=false

# Make sure kube-ui addon is enabled.
export ENABLE_CLUSTER_UI=true

# Provided for backwards compatibility, see ${KUBE_ROOT}/hack/e2e-test.sh.
go run "$(dirname $0)/../e2e.go" -v -build -up -test --test_args="--ginkgo.skip=${CAICLOUD_TEST_SKIP_REGEX}" -down

# To run a dedicated test, use --test_args="--ginkgo.focus=*", for example:
# go run "$(dirname $0)/../e2e.go" -v -build -up -test --test_args="--ginkgo.focus=Guestbook.*working application" -down

exit $?
