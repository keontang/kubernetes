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

# TODO: implement this

# The script creates an instance with:
#   1. cluster binaries installed;
#   2. docker and bridge-utils installed
#
# The instance is supposed to be used to create a base image.

set -e


# Release version for creating cluster.
ETCD_VERSION="v2.0.9"
FLANNEL_VERSION="0.4.0"
K8S_VERSION="v0.18.2"



# Download release to a temp dir, organized by master and node. E.g.
#  /tmp/kubernetes.EuWJ4M/master
#  /tmp/kubernetes.EuWJ4M/node
#
# TODO: We should use our own k8s release, of course :)
#
# Assumed vars:
#   ETCD_VERSION
#   FLANNEL_VERSION
#   K8S_VERSION
#
# Vars set:
#   KUBE_TEMP (call to ensure-temp-dir)
function download-release {
  ensure-temp-dir

  mkdir "${KUBE_TEMP}"/master
  mkdir "${KUBE_TEMP}"/node

  (cd "${KUBE_TEMP}"
   # TODO: Anchnet has private SDN tool, we can investigate it later and
   # can hopefully remove dependency on flannel.
   echo "Download flannel release ..."
   if [ ! -f flannel.tar.gz ] ; then
     curl -L  https://github.com/coreos/flannel/releases/download/v${FLANNEL_VERSION}/flannel-${FLANNEL_VERSION}-linux-amd64.tar.gz -o flannel.tar.gz
     tar xzf flannel.tar.gz
   fi
   # Put flanneld in master also we can use kubectl proxy.
   cp flannel-${FLANNEL_VERSION}/flanneld master
   cp flannel-${FLANNEL_VERSION}/flanneld node

   echo "Download etcd release ..."
   ETCD="etcd-${ETCD_VERSION}-linux-amd64"
   if [ ! -f etcd.tar.gz ] ; then
     curl -L https://github.com/coreos/etcd/releases/download/${ETCD_VERSION}/${ETCD}.tar.gz -o etcd.tar.gz
     tar xzf etcd.tar.gz
   fi
   cp $ETCD/etcd $ETCD/etcdctl master
   cp $ETCD/etcd $ETCD/etcdctl node

   echo "Download kubernetes release ..."
   if [ ! -f kubernetes.tar.gz ] ; then
     curl -L https://github.com/GoogleCloudPlatform/kubernetes/releases/download/${K8S_VERSION}/kubernetes.tar.gz -o kubernetes.tar.gz
     tar xzf kubernetes.tar.gz
   fi
   pushd kubernetes/server
   tar xzf kubernetes-server-linux-amd64.tar.gz
   popd
   cp kubernetes/server/kubernetes/server/bin/kube-apiserver \
      kubernetes/server/kubernetes/server/bin/kube-controller-manager \
      kubernetes/server/kubernetes/server/bin/kube-scheduler master
   cp kubernetes/server/kubernetes/server/bin/kubelet \
      kubernetes/server/kubernetes/server/bin/kube-proxy node
   rm -rf flannel* kubernetes* etcd*

   echo "Done! Downloaded all components in ${KUBE_TEMP}"
  )
}
