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

# The file contains configuration values that vary per user. Some values
# are specified by users, e.g. NODE_MEM; and some values are specified by
# cluster executor.

# Unique ID of the cluster.
export CLUSTER_ID=${CLUSTER_ID-"kube-default"}

# Define number of nodes (minions). There will be only one master.
export NUM_MINIONS=${NUM_MINIONS-1}

# The memory size of master node (in MB).
export MASTER_MEM=${MASTER_MEM-1024}
# The number of CPUs of the master.
export MASTER_CPU_CORES=${MASTER_CPU_CORES-1}

# The memory size of master node (in MB).
export NODE_MEM=${NODE_MEM-1024}
# The number of CPUs of a node.
export NODE_CPU_CORES=${NODE_CPU_CORES-1}
