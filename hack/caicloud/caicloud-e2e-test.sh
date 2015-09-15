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

# This will be used during e2e as ssh user to execute command inside nodes.
export KUBE_SSH_USER=${KUBE_SSH_USER:-"ubuntu"}

# Add skipped test regex here.
CAICLOUD_TEST_SKIP_REGEX=${CAICLOUD_TEST_SKIP_REGEX:-"kube-ui"}

# Provided for backwards compatibility, see ${KUBE_ROOT}/hack/e2e-test.sh.
go run "$(dirname $0)/../e2e.go" -v -build -up -test --test_args="--ginkgo.skip=${CAICLOUD_TEST_SKIP_REGEX}" -down

# To run a dedicated test, use --test_args="--ginkgo.focus=*", for example:
# go run "$(dirname $0)/../e2e.go" -v -build -up -test --test_args="--ginkgo.focus=Guestbook.*working application" -down

exit $?
