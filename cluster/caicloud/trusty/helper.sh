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

# Create master startup script and send all config files to master.
#
# Input:
#   $1 Master ssh info, e.g. "root:password@43.254.54.59"
#   $2 Interface or IP address used by flanneld to send internal traffic.
#      If empty, master IP address from above will be used.
#   $3 Cloudprovider name, leave empty if running without cloudprovider.
#      Otherwise, all k8s components will see the cloudprovider, and read
#      config file from /etc/kubernetes/cloud-config.
#   $4 Cloudprovider config file, leave empty if the cloudprovider doesn't
#      have a config file.
#
# Assumed vars:
#   KUBE_TEMP
#   KUBE_ROOT
#   ADMISSION_CONTROL
#   CLUSTER_NAME
#   FLANNEL_NET
#   KUBERNETES_PROVIDER
#   SERVICE_CLUSTER_IP_RANGE
function send-master-startup-config-files {
  if [[ "${2:-}" != "" ]]; then
    interface="${2}"
  else
    IFS=':@' read -ra ssh_info <<< "${1}"
    interface="${ssh_info[2]}"
  fi
  send-master-startup-config-files-internal "${1}" "${interface}" "${3:-}" "${4:-}"
}
# Input:
#   $1 Master ssh info.
#   $2 Interface or IP address used by flanneld to send internal traffic.
#   $3 Cloudprovider name.
#   $4 Cloudprovider config file.
function send-master-startup-config-files-internal {
  mkdir -p ${KUBE_TEMP}/kube-master/kube/master
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
    # Remove rwx permission on folders we don't want user to mess up with
    echo "sudo chmod go-rwx /opt/bin /etc/kubernetes"
    # Finally, start kubernetes cluster. Upstart will make sure all components start
    # upon etcd start.
    echo "sudo service etcd start"
    # After starting etcd, configure flannel options.
    echo "config-etcd-flanneld ${FLANNEL_NET}"
  ) > ${KUBE_TEMP}/kube-master/kube/master-start.sh
  chmod a+x ${KUBE_TEMP}/kube-master/kube/master-start.sh

  cp -r ${KUBE_ROOT}/cluster/caicloud/trusty/master/init_conf \
     ${KUBE_ROOT}/cluster/caicloud/trusty/master/init_scripts \
     ${KUBE_TEMP}/known-tokens.csv \
     ${KUBE_TEMP}/basic-auth.csv \
     ${KUBE_TEMP}/easy-rsa-master/easyrsa3/pki/ca.crt \
     ${KUBE_TEMP}/easy-rsa-master/easyrsa3/pki/issued/master.crt \
     ${KUBE_TEMP}/easy-rsa-master/easyrsa3/pki/private/master.key \
     ${KUBE_TEMP}/kubelet-kubeconfig \
     ${KUBE_TEMP}/kube-proxy-kubeconfig \
     ${KUBE_TEMP}/kube-master/kube
  if [[ "${4:-}" != "" ]]; then
    cp ${4} ${KUBE_TEMP}/kube-master/kube/cloud-config
  fi
  scp-to-instance-expect "${1}" "${KUBE_TEMP}/kube-master/kube" "~"

  ssh-to-instance "${1}" "sudo cp ~/kube/kubelet-kubeconfig ~/kube/kube-proxy-kubeconfig /etc/caicloud"
}

# Create node startup script and send all config files to nodes.
#
# Input:
#   $1 Master ssh info, e.g. "root:password@43.254.54.59"
#   $2 Node ssh info, e.g. "root:password@43.254.54.59,root:password@43.254.54.60"
#   $3 Master internal IP.
#   $4 Interface or IP address used by flanneld to send internal traffic.
#      If empty, node IP address will be used.
#   $5 Hostname overrides, leave empty if no hostname override is necessary.
#   $6 Cloudprovider name, leave empty if running without cloudprovider.
#      Otherwise, all k8s components will see the cloudprovider, and read
#      config file from /etc/kubernetes/cloud-config.
#   $7 Cloudprovider config file, leave empty if the cloudprovider doesn't
#      have a config file.
#
# Assumed vars:
#   KUBE_TEMP
#   KUBE_ROOT
#   DNS_DOMAIN
#   DNS_SERVER_IP
#   KUBELET_IP_ADDRESS
#   MASTER_IIP
#   PRIVATE_SDN_INTERFACE
#   POD_INFRA_CONTAINER
#   REG_MIRROR
function send-node-startup-config-files {
  # Randomly choose one daocloud accelerator.
  find-registry-mirror

  # Get array of hostnames to override if necessary.
  if [[ "${5:-}" != "" ]]; then
    IFS=',' read -ra hostname_arr <<< "${5}"
  fi

  local pids=""
  IFS=',' read -ra node_ssh_info <<< "${2}"
  for (( i = 0; i < ${#node_ssh_info[*]}; i++ )); do
    if [[ "${4:-}" != "" ]]; then
      interface="${4}"
    else
      IFS=':@' read -ra ssh_info <<< "${node_ssh_info[$i]}"
      interface="${ssh_info[2]}"
    fi
    if [[ "${5:-}" != "" ]]; then
      hostname_override="${hostname_arr[$i]}"
    else
      hostname_override=""
    fi
    send-node-startup-config-files-internal \
      "${1}" \
      "${node_ssh_info[$i]}" \
      "${3}" \
      "${interface}" \
      "${hostname_override}" \
      "${6:-}" \
      "${7:-}" & pids="${pids} $!"
  done
  wait ${pids}
}
# Input:
#   $1 Master ssh info, e.g. "root:password@43.254.54.59"
#   $2 Node ssh info, e.g. "root:password@43.254.54.59"
#   $3 Master internal IP.
#   $4 Interface or IP address used by flanneld to send internal traffic.
#   $5 Hostname override
#   $6 Cloudprovider name
#   $7 Cloudprovider config file
function send-node-startup-config-files-internal {
  mkdir -p ${KUBE_TEMP}/kube-node${2}/kube/node
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
    if [[ "${6:-}" != "" ]]; then
      echo "create-kubelet-opts ${KUBELET_IP_ADDRESS} ${DNS_SERVER_IP} ${DNS_DOMAIN} ${POD_INFRA_CONTAINER} true \"${5:-}\" ${3} ${6} /etc/kubernetes/cloud-config"
    else
      echo "create-kubelet-opts ${KUBELET_IP_ADDRESS} ${DNS_SERVER_IP} ${DNS_DOMAIN} ${POD_INFRA_CONTAINER} true \"${5:-}\" ${3}"
    fi
    echo "create-kube-proxy-opts 'node' ${3}"
    echo "create-flanneld-opts ${4} ${3}"
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
    echo "restart-docker ${REG_MIRROR} /etc/default/docker"
  ) > ${KUBE_TEMP}/kube-node${2}/kube/node-start.sh
  chmod a+x ${KUBE_TEMP}/kube-node${2}/kube/node-start.sh

  cp -r ${KUBE_ROOT}/cluster/caicloud/trusty/node/init_conf \
     ${KUBE_ROOT}/cluster/caicloud/trusty/node/init_scripts \
     ${KUBE_ROOT}/cluster/caicloud/trusty/manifest/fluentd-es.yaml \
     ${KUBE_ROOT}/cluster/caicloud/nsenter \
     ${KUBE_TEMP}/kube-node${2}/kube
  if [[ "${7:-}" != "" ]]; then
    cp ${7} ${KUBE_TEMP}/kube-node${2}/kube/cloud-config
  fi
  scp-to-instance-expect "${2}" "${KUBE_TEMP}/kube-node${2}/kube" "~"

  # Fetch kubelet-kubeconfig & kube-proxy-kubeconfig from master
  IFS=':@' read -ra master_ssh_info <<< "${1}"
  IFS=':@' read -ra ssh_info <<< "${2}"
  expect <<EOF
set timeout -1
spawn ssh -t -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
  ${master_ssh_info[0]}@${master_ssh_info[2]} \
"sudo scp -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
  ~/kube/kubelet-kubeconfig ~/kube/kube-proxy-kubeconfig ${ssh_info[0]}@${ssh_info[2]}:~/kube"

expect {
  "*?assword*" {
    send -- "${ssh_info[1]}\r"
    exp_continue
  }
  "?ommand failed" {exit 1}
  "lost connection" { exit 1 }
  eof {}
}
EOF
}

# Install binaries from local directory.
#
# Inputs:
#   $1 Master ssh info, e.g. "root:password@43.254.54.59"
#   $2 Node ssh info, e.g. "root:password@43.254.54.59,root:password@43.254.54.60"
function install-binaries-from-local {
  # Get the caicloud kubernetes release tarball.
  fetch-and-extract-tarball
  # Copy binaries to master
  rm -rf ${KUBE_TEMP}/kube && mkdir -p ${KUBE_TEMP}/kube/master
  cp -r ${KUBE_TEMP}/caicloud-kube/etcd \
     ${KUBE_TEMP}/caicloud-kube/etcdctl \
     ${KUBE_TEMP}/caicloud-kube/flanneld \
     ${KUBE_TEMP}/caicloud-kube/kubectl \
     ${KUBE_TEMP}/caicloud-kube/kubelet \
     ${KUBE_TEMP}/caicloud-kube/kube-apiserver \
     ${KUBE_TEMP}/caicloud-kube/kube-scheduler \
     ${KUBE_TEMP}/caicloud-kube/kube-controller-manager \
     ${KUBE_TEMP}/kube/master
  scp-to-instance-expect "${1}" "${KUBE_TEMP}/kube" "~"
  # Copy binaries to nodes.
  rm -rf ${KUBE_TEMP}/kube && mkdir -p ${KUBE_TEMP}/kube/node
  IFS=',' read -ra node_ssh_info <<< "${2}"
  for (( i = 0; i < ${#node_ssh_info[*]}; i++ )); do
    cp -r ${KUBE_TEMP}/caicloud-kube/etcd \
       ${KUBE_TEMP}/caicloud-kube/etcdctl \
       ${KUBE_TEMP}/caicloud-kube/flanneld \
       ${KUBE_TEMP}/caicloud-kube/kubelet \
       ${KUBE_TEMP}/caicloud-kube/kube-proxy \
       ${KUBE_TEMP}/kube/node
    scp-to-instance-expect "${node_ssh_info[$i]}" "${KUBE_TEMP}/kube" "~"
  done
}

# Fetch tarball in master instance.
#
# Inputs:
#   $1 Master external ssh info, e.g. "root:password@43.254.54.59"
function fetch-tarball-in-master {
  command-exec-and-retry "fetch-tarball-in-master-internal ${1}" 2 "false"
}
function fetch-tarball-in-master-internal {
  log "+++++ Start fetching and installing tarball from: ${CAICLOUD_TARBALL_URL}."

  # Fetch tarball for master node.
  ssh-to-instance-expect "${1}" "wget ${CAICLOUD_TARBALL_URL} -O ~/caicloud-kube.tar.gz && \
sudo mkdir -p /etc/caicloud && sudo cp ~/caicloud-kube.tar.gz /etc/caicloud && \
sudo chmod go-rwx /etc/caicloud"
}

# Distribute tarball from master to nodes. After installation, each node will
# have binaires in ~/kube/master and ~/kube/node. Note, we MUST be able to ssh
# to master without using password.
#
# Inputs:
#   $1 Master external ssh info, e.g. "root:password@43.254.54.59"
#   $2 Node external ssh info, e.g. "root:password@43.254.54.59,root:password@43.254.54.60"
#   $3 Node internal ssh info, e.g. "root:password@10.0.0.0,root:password@10.0.0.1".
#      Since we distribute tarball from master to nodes, it's better to use internal
#      address. Leave empty if no internal address is available.
#
# Assumed vars:
#   KUBE_INSTANCE_LOGDIR
#   CAICLOUD_TARBALL_URL
function install-binaries-from-master {
  command-exec-and-retry "install-binaries-from-master-internal ${1} ${2} ${3}" 2 "false"
}
function install-binaries-from-master-internal {
  local pids=""
  local fail=0

  # Distribute tarball from master to nodes. Use internal address if possible.
  if [[ -z "${3:-}" ]]; then
    IFS=',' read -ra node_ssh_info <<< "${2}"
  else
    IFS=',' read -ra node_ssh_info <<< "${3}"
  fi
  IFS=':@' read -ra master_ssh_info <<< "${1}"
  for (( i = 0; i < ${#node_ssh_info[*]}; i++ )); do
    IFS=':@' read -ra ssh_info <<< "${node_ssh_info[$i]}"
    expect <<EOF &
set timeout -1
spawn ssh -t -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
  ${master_ssh_info[0]}@${master_ssh_info[2]} \
"sudo cp /etc/caicloud/caicloud-kube.tar.gz ~/ && \
scp -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
  ~/caicloud-kube.tar.gz ${ssh_info[0]}@${ssh_info[2]}:~/caicloud-kube.tar.gz"

expect {
  "*?assword*" {
    send -- "${ssh_info[1]}\r"
    exp_continue
  }
  "?ommand failed" {exit 1}
  "lost connection" { exit 1 }
  eof {}
}
EOF
    pids="$pids $!"
  done

  wait-pids "${pids}" "+++++ Wait for tarball to be distributed to all nodes"
  if [[ "$?" != "0" ]]; then
    return 1
  fi

  # Extract and install tarball for all instances.
  pids=""
  IFS=',' read -ra instance_ssh_info <<< "${1},${2}"
  for (( i = 0; i < ${#instance_ssh_info[*]}; i++ )); do
    ssh-to-instance-expect "${instance_ssh_info[$i]}" "\
tar xvzf caicloud-kube.tar.gz && mkdir -p ~/kube/master && \
cp caicloud-kube/etcd caicloud-kube/etcdctl caicloud-kube/flanneld caicloud-kube/kube-apiserver \
  caicloud-kube/kube-controller-manager caicloud-kube/kubectl caicloud-kube/kube-scheduler ~/kube/master && \
mkdir -p ~/kube/node && \
cp caicloud-kube/etcd caicloud-kube/etcdctl caicloud-kube/flanneld caicloud-kube/kubectl \
  caicloud-kube/kubelet caicloud-kube/kube-proxy ~/kube/node && \
rm -rf caicloud-kube.tar.gz caicloud-kube || \
echo 'Command failed installing tarball binaries on remote host ${instance_ssh_info[$i]}'" &
    pids="$pids $!"
  done

  wait-pids "${pids}" "+++++ Wait for all instances to install tarball"
}

# Install packages for all nodes. The packages are required for running
# kubernetes nodes.
#
# Input:
#   $1 Node ssh info, e.g. "root:password@43.254.54.59,root:password@43.254.54.60"
#   $2 report failure; if true, report failure to caicloud cluster manager.
#
# Assumed vars:
#   APT_MIRRORS
#   KUBE_INSTANCE_LOGDIR
function install-packages {
  APT_MIRROR_INDEX=0            # Used for choosing an apt mirror.
  command-exec-and-retry "install-packages-internal ${1}" 2 "${2-}"
}
function install-packages-internal {
  log "+++++ Start installing packages."

  # Choose an apt-mirror for installing packages.
  IFS=',' read -ra apt_mirror_arr <<< "${APT_MIRRORS}"
  apt_mirror=${apt_mirror_arr[$(( ${APT_MIRROR_INDEX} % ${#apt_mirror_arr[*]} ))]}
  log "Use apt mirror ${apt_mirror}"

  # Install packages for given nodes concurrently.
  local pids=""
  IFS=',' read -ra node_ssh_info <<< "${1}"
  for ssh_info in "${node_ssh_info[@]}"; do
    IFS=':@' read -ra ssh_info <<< "${ssh_info}"
    expect <<EOF &
set timeout -1

spawn ssh -t -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
  ${ssh_info[0]}@${ssh_info[2]} "\
sudo sh -c 'cat > /etc/apt/sources.list' << EOL
deb ${apt_mirror} trusty main restricted universe multiverse
deb ${apt_mirror} trusty-security main restricted universe multiverse
deb ${apt_mirror} trusty-updates main restricted universe multiverse
deb-src ${apt_mirror} trusty main restricted universe multiverse
deb-src ${apt_mirror} trusty-security main restricted universe multiverse
deb-src ${apt_mirror} trusty-updates main restricted universe multiverse
EOL
sudo sh -c 'cat > /etc/apt/sources.list.d/docker.list' << EOL
deb \[arch=amd64\] http://get.caicloud.io/docker ubuntu-trusty main
EOL
sudo apt-get update && \
sudo apt-get install --allow-unauthenticated -y docker-engine=${DOCKER_VERSION}-0~trusty && \
sudo apt-get install bridge-utils socat || \
echo 'Command failed installing packages on remote host $1'"

expect {
  "*?assword*" {
    send -- "${ssh_info[1]}\r"
    exp_continue
  }
  "Command failed" {exit 1}
  "lost connection" { exit 1 }
  eof {}
}
EOF
    pids="$pids $!"
  done

  wait-pids "${pids}" "+++++ Wait for all instances to install packages"
}

# Set hostname of an instance. In anchnet, hostname has the same format but
# different value than instance ID. We don't need the random hostname given
# by anchnet.
#
# Input:
#   $1 instance ID
function config-hostname {
  # Lowercase input value.
  local new_hostname=$(echo $1 | tr '[:upper:]' '[:lower:]')

  # Return early if hostname is already new.
  if [[ "`hostname`" == "${new_hostname}" ]]; then
    return
  fi

  if which hostnamectl > /dev/null; then
    hostnamectl set-hostname "${new_hostname}"
  else
    echo "${new_hostname}" > /etc/hostname
    hostname "${new_hostname}"
  fi

  if grep '127\.0\.1\.1' /etc/hosts > /dev/null; then
    sed -i "s/127\.0\.1\.1.*/127.0.1.1 ${new_hostname}/g" /etc/hosts
  else
    echo -e "127.0.1.1\t${new_hostname}" >> /etc/hosts
  fi

  echo "Hostname settings have been changed to ${new_hostname}."
}

# Add an entry in /etc/hosts file if not already exists. This is used for master to
# contact kubelet using hostname, as anchnet is unable to do hostname resolution.
#
# Input:
#   $1 hostname
#   $2 host IP address
function add-hosts-entry {
  # Lowercase input value.
  local new_hostname=$(echo $1 | tr '[:upper:]' '[:lower:]')

  if ! grep "$new_hostname" /etc/hosts > /dev/null; then
    echo -e "$2 $new_hostname" >> /etc/hosts
  fi
}

# Setup network restart network manager. Make sure to copy interface config to
# /etc/network/interfaces if necessary.
function setup-network {
  sed -i 's/^managed=false/managed=true/' /etc/NetworkManager/NetworkManager.conf
  service network-manager restart
}
