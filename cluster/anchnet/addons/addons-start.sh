#!/bin/bash

function start_addon() {
  tries=$2
  delay=$3
  while [ ${tries} -gt 0 ]; do
    sudo /opt/bin/kubectl create -f $1 && \
      return 0;
    let tries=tries-1;
    echo "== Failed to start $1. ${tries} tries remaining. =="
    sleep ${delay};
  done
  return 1;
}

mkdir -p ~/kube/addons
mv ~/kube/system:dns-secret ~/kube/skydns-rc.yaml ~/kube/skydns-svc.yaml ~/kube/addons
for obj in $(find ~/kube/addons -type f);do
  start_addon ${obj} 10 10 &
  echo "++ obj ${obj} is created ++"
done
