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

# Reconfigure docker network setting.

function reconfig-docker-net {
  if [ "$(id -u)" != "0" ]; then
    echo >&2 "Please run as root"
    exit 1
  fi

  attempt=0
  while true; do
    /opt/bin/etcdctl get /coreos.com/network/config
    if [[ "$?" == 0 ]]; then
      break
    else
      # TODO: Timeout seems arbitrary.
      if (( attempt > 600 )); then
        echo "timeout for waiting network config" > ~/kube/err.log
        exit 2
      fi

      /opt/bin/etcdctl mk /coreos.com/network/config "{\"Network\":\"${FLANNEL_NET}\"}"
      attempt=$((attempt+1))
      sleep 3
    fi
  done

  # Wait for /run/flannel/subnet.env to be ready.
  # TODO: Sleep seems arbitrary.
  sleep 15

  # In order for docker to correctly use flannel setting, we first stop docker,
  # flush nat table, delete docker0 and then start docker. Missing any one of
  # the steps may result in wrong iptable rules, see:
  # https://github.com/caicloud/caicloud-kubernetes/issues/25
  sudo service docker stop
  iptables -t nat -F
  sudo ip link set dev docker0 down
  sudo brctl delbr docker0

  source /run/flannel/subnet.env

  echo DOCKER_OPTS=\"-H tcp://127.0.0.1:4243 -H unix:///var/run/docker.sock \
       --bip=${FLANNEL_SUBNET} --mtu=${FLANNEL_MTU}\" > /etc/default/docker
  sudo service docker start
}
