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

#
# The script contains utilities used to provision kubernetes cluster
# for ubuntu:trusty.
#

# Create a script to start a fresh master.
#
# Input:
#   $1 File path used to store the script, e.g. /tmp/master1-script.sh
#   $2 Interface or IP address used by flanneld to send internal traffic.
#   $3 Cloudprovider name, leave empty if running without cloudprovider.
#      Otherwise, all k8s components will see the cloudprovider, and read
#      config file from /etc/kubernetes/cloud-config.
#
# Assumed vars:
#   ADMISSION_CONTROL
#   CLUSTER_NAME
#   FLANNEL_NET
#   KUBE_ROOT
#   KUBERNETES_PROVIDER
#   SERVICE_CLUSTER_IP_RANGE
function create-master-start-script {
  (
    echo "#!/bin/bash"
    grep -v "^#" "${KUBE_ROOT}/cluster/caicloud/config-components.sh"
    grep -v "^#" "${KUBE_ROOT}/cluster/${KUBERNETES_PROVIDER}/config-default.sh"
    echo ""
    echo "mkdir -p ~/kube/configs"
    # The following create-*-opts functions create component options (flags).
    # The flag options are stored under ~/kube/configs.
    if [[ "${3:-}" != "" ]]; then
      echo "create-kube-apiserver-opts ${CLUSTER_NAME} ${SERVICE_CLUSTER_IP_RANGE} ${ADMISSION_CONTROL} ${3} /etc/kubernetes/cloud-config"
      echo "create-kube-controller-manager-opts ${CLUSTER_NAME} ${3} /etc/kubernetes/cloud-config"
    else
      echo "create-kube-apiserver-opts ${CLUSTER_NAME} ${SERVICE_CLUSTER_IP_RANGE} ${ADMISSION_CONTROL}"
      echo "create-kube-controller-manager-opts ${CLUSTER_NAME}"
    fi
    echo "create-kube-scheduler-opts"
    echo "create-etcd-opts kubernetes-master"
    echo "create-flanneld-opts ${2} 127.0.0.1"
    # Create the system directories used to hold the final data.
    echo "sudo mkdir -p /opt/bin"
    echo "sudo mkdir -p /etc/kubernetes"
    echo "sudo mkdir -p /etc/kubernetes/manifest"
    # Since we might retry on error during kube-pu, we need to stop services.
    # If no service is running, this is just no-op.
    echo "sudo service etcd stop"
    # Copy binaries and configurations to system directories.
    echo "sudo cp ~/kube/master/* /opt/bin"
    echo "sudo cp ~/kube/configs/* /etc/default"
    echo "sudo cp ~/kube/init_conf/* /etc/init/"
    echo "sudo cp ~/kube/init_scripts/* /etc/init.d/"
    echo "sudo cp ~/kube/known-tokens.csv ~/kube/basic-auth.csv /etc/kubernetes"
    echo "sudo cp ~/kube/ca.crt ~/kube/master.crt ~/kube/master.key /etc/kubernetes"
    # Make sure cloud-config exists, even if not used.
    echo "touch ~/kube/cloud-config && sudo cp ~/kube/cloud-config /etc/kubernetes"
    # Finally, start kubernetes cluster. Upstart will make sure all components start
    # upon etcd start.
    echo "sudo service etcd start"
    # After starting etcd, configure flannel options.
    echo "config-etcd-flanneld ${FLANNEL_NET}"
  ) > "$1"
  chmod a+x "$1"
}

# Create a node start script used to start a fresh node.
#
# Input:
#   $1 File to store the script.
#   $2 Master internal IP.
#   $3 Daocloud mirror for the node.
#   $4 Interface or IP address used by flanneld to send internal traffic.
#   $5 Cloudprovider name, leave empty if running without cloudprovider.
#      Otherwise, all k8s components will see the cloudprovider, and read
#      config file from /etc/kubernetes/cloud-config.
#
# Assumed vars:
#   DNS_DOMAIN
#   DNS_SERVER_IP
#   KUBELET_IP_ADDRESS
#   MASTER_IIP
#   PRIVATE_SDN_INTERFACE
#   POD_INFRA_CONTAINER
function create-node-start-script {
  # Create node startup script. Note we assume the base image has necessary
  # tools installed, e.g. docker, bridge-util, etc. The flow is similar to
  # master startup script.
  (
    echo "#!/bin/bash"
    grep -v "^#" "${KUBE_ROOT}/cluster/caicloud/config-components.sh"
    grep -v "^#" "${KUBE_ROOT}/cluster/${KUBERNETES_PROVIDER}/config-default.sh"
    echo ""
    echo "mkdir -p ~/kube/configs"
    # Create component options.
    if [[ "${5:-}" != "" ]]; then
      echo "create-kubelet-opts ${KUBELET_IP_ADDRESS} ${DNS_SERVER_IP} ${DNS_DOMAIN} ${POD_INFRA_CONTAINER} true '' ${2} ${5} /etc/kubernetes/cloud-config"
    else
      echo "create-kubelet-opts ${KUBELET_IP_ADDRESS} ${DNS_SERVER_IP} ${DNS_DOMAIN} ${POD_INFRA_CONTAINER} true '' ${2}"
    fi
    echo "create-kube-proxy-opts 'node' ${2}"
    echo "create-flanneld-opts ${4} ${2}"
    # Create the system directories used to hold the final data.
    echo "sudo mkdir -p /opt/bin"
    echo "sudo mkdir -p /etc/kubernetes"
    echo "sudo mkdir -p /etc/kubernetes/manifest"
    # Since we might retry on error, we need to stop services. If no service
    # is running, this is just no-op.
    echo "sudo service flanneld stop"
    # Copy binaries and configurations to system directories.
    echo "sudo cp ~/kube/node/* /opt/bin"
    echo "sudo cp ~/kube/nsenter /usr/local/bin"
    echo "sudo cp ~/kube/configs/* /etc/default"
    echo "sudo cp ~/kube/init_conf/* /etc/init/"
    echo "sudo cp ~/kube/init_scripts/* /etc/init.d/"
    echo "sudo cp ~/kube/fluentd-es.yaml /etc/kubernetes/manifest"
    echo "sudo cp ~/kube/kubelet-kubeconfig ~/kube/kube-proxy-kubeconfig /etc/kubernetes"
    # Make sure cloud-config exists, even if not used.
    echo "touch ~/kube/cloud-config && sudo cp ~/kube/cloud-config /etc/kubernetes"
    # Finally, start kubernetes cluster. Upstart will make sure all components
    # start upon flannel start.
    echo "sudo service flanneld start"
    # After starting flannel, configure docker network to use flannel overlay.
    echo "restart-docker ${3} /etc/default/docker"
  ) > "$1"
  chmod a+x "$1"
}

# Send all necessary files to master, after which, we can just call master start
# script to start kubernetes master. Some of the files exist in the repo, some are
# generated dynamically, some are fetched from remote host.
#
# Input:
#   $1 username and node address, e.g. ubuntu@43.254.54.14
#   $2 optional passward if needed
function send-files-to-master {
  rm -rf ${KUBE_TEMP}/kube && mkdir -p ${KUBE_TEMP}/kube/master
  # Copy config files.
  cp -r ${KUBE_ROOT}/cluster/caicloud/trusty/master/init_conf \
     ${KUBE_ROOT}/cluster/caicloud/trusty/master/init_scripts \
     ${KUBE_TEMP}/master-start.sh \
     ${KUBE_TEMP}/known-tokens.csv \
     ${KUBE_TEMP}/basic-auth.csv \
     ${KUBE_TEMP}/easy-rsa-master/easyrsa3/pki/ca.crt \
     ${KUBE_TEMP}/easy-rsa-master/easyrsa3/pki/issued/master.crt \
     ${KUBE_TEMP}/easy-rsa-master/easyrsa3/pki/private/master.key \
     ${KUBE_TEMP}/kube
  # Copy binaries.
  cp -r ${KUBE_TEMP}/caicloud-kube/etcd \
     ${KUBE_TEMP}/caicloud-kube/etcdctl \
     ${KUBE_TEMP}/caicloud-kube/flanneld \
     ${KUBE_TEMP}/caicloud-kube/kubectl \
     ${KUBE_TEMP}/caicloud-kube/kubelet \
     ${KUBE_TEMP}/caicloud-kube/kube-apiserver \
     ${KUBE_TEMP}/caicloud-kube/kube-scheduler \
     ${KUBE_TEMP}/caicloud-kube/kube-controller-manager \
     ${KUBE_TEMP}/kube/master
  if [[ -f ${KUBE_TEMP}/cloud-config ]]; then
    cp ${KUBE_TEMP}/cloud-config ${KUBE_TEMP}/kube
  fi
  scp-to-instance "${KUBE_TEMP}/kube" "${1}" "~" "${2:-}"
}

# Send all necessary files to node, after which, we can just call node start
# script to start kubernetes node.
#
# Input:
#   $1 username and node address, e.g. ubuntu@43.254.54.14
#   $2 optional passward if needed
function send-files-to-node {
  rm -rf ${KUBE_TEMP}/kube && mkdir -p ${KUBE_TEMP}/kube/node
  # Copy config files.
  cp -r ${KUBE_ROOT}/cluster/caicloud/trusty/node/init_conf \
     ${KUBE_ROOT}/cluster/caicloud/trusty/node/init_scripts \
     ${KUBE_ROOT}/cluster/caicloud/trusty/manifest/fluentd-es.yaml \
     ${KUBE_ROOT}/cluster/caicloud/nsenter \
     ${KUBE_TEMP}/node${i}/node-start.sh \
     ${KUBE_TEMP}/kubelet-kubeconfig \
     ${KUBE_TEMP}/kube-proxy-kubeconfig \
     ${KUBE_TEMP}/kube
  # Copy binaries.
  cp -r ${KUBE_TEMP}/caicloud-kube/etcd \
     ${KUBE_TEMP}/caicloud-kube/etcdctl \
     ${KUBE_TEMP}/caicloud-kube/flanneld \
     ${KUBE_TEMP}/caicloud-kube/kubelet \
     ${KUBE_TEMP}/caicloud-kube/kube-proxy \
     ${KUBE_TEMP}/kube/node
  if [[ -f ${KUBE_TEMP}/cloud-config ]]; then
    cp ${KUBE_TEMP}/cloud-config ${KUBE_TEMP}/kube
  fi
  scp-to-instance "${KUBE_TEMP}/kube" "${1}" "~" "${2:-}"
}

# Install packages for a given node.
#
# Input:
#   $1 username and node address, e.g. ubuntu@43.254.54.14
#   $2 optional passward if needed
function install-packages {
  APT_MIRROR_INDEX=0            # Not used for now.
  IFS=',' read -ra apt_mirror_arr <<< "${APT_MIRRORS}"
  apt_mirror=${apt_mirror_arr[$(( ${APT_MIRROR_INDEX} % ${#apt_mirror_arr[*]} ))]}

  expect <<EOF
set timeout -1

spawn ssh -t -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
  ${1} "\
sudo sh -c 'cat > /etc/apt/sources.list' << EOL
deb ${apt_mirror} trusty main restricted universe multiverse
deb ${apt_mirror} trusty-security main restricted universe multiverse
deb ${apt_mirror} trusty-updates main restricted universe multiverse
deb-src ${apt_mirror} trusty main restricted universe multiverse
deb-src ${apt_mirror} trusty-security main restricted universe multiverse
deb-src ${apt_mirror} trusty-updates main restricted universe multiverse
EOL
sudo sh -c 'cat > /etc/apt/sources.list.d/docker.list' << EOL
deb \[arch=amd64\] http://get.bitintuitive.com/repo ubuntu-trusty main
EOL
sudo apt-get update && \
sudo apt-get install --allow-unauthenticated -y docker-engine=${DOCKER_VERSION}-0~trusty && \
sudo apt-get install bridge-utils socat || \
echo 'Command failed installing packages on remote host $1'"

expect {
  "*?assword*" {
    send -- "${2}\r"
    exp_continue
  }
  "Command failed" {exit 1}
  "lost connection" { exit 1 }
  eof {}
}
EOF
}
