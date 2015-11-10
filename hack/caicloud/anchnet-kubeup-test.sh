#!/bin/bash

# Path of kubernetes root directory.
KUBE_ROOT="$(dirname "${BASH_SOURCE}")/../.."

rm -rf /tmp/test && mkdir /tmp/test

cd ${KUBE_ROOT}

count=0
while true; do
  count=$((count + 1))
  echo "Executing count ${count}"
  KUBERNETES_PROVIDER=caicloud-anchnet NUM_MINIONS=4 ./cluster/kube-up.sh > /tmp/test/$count 2>&1
  sleep 900                     # sleep 15min
  kubectl get nodes -o wide >> /tmp/test/$count 2>&1
  kubectl get pods --all-namespaces -o wide >> /tmp/test/$count 2>&1
  KUBERNETES_PROVIDER=caicloud-anchnet ./cluster/kube-down.sh >> /tmp/test/$count 2>&1
  sleep 300                     # sleep 5min
done

cd - > /dev/null
