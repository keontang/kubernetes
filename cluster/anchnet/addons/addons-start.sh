#!/bin/bash

function create_resource_from_file() {
  tries=$2
  delay=$3
  while [ ${tries} -gt 0 ]; do
    sudo /opt/bin/kubectl create -f $1 && \
      echo "== Successfully started $1 at $(date -Is)" && \
      return 0;
    let tries=tries-1;
    echo "== Failed to start $1. ${tries} tries remaining. =="
    sleep ${delay};
  done
  return 1;
}

mkdir -p ~/kube/addons
mv ~/kube/system:dns-secret ~/kube/skydns-rc.yaml ~/kube/skydns-svc.yaml ~/kube/addons

# Create secret before the addons which have dependencies on it.
create_resource_from_file ~/kube/addons/system:dns-secret 10 10

# Create addons from file
for obj in $(find ~/kube/addons -type f -name \*.yaml -o -name \*.json);do
  create_resource_from_file ${obj} 10 10
  echo "++ obj ${obj} is created ++"
done
