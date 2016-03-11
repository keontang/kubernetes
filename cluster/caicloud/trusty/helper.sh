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

# Create master scripts and config files, then send to master.
#
# Assumed vars:
#   KUBE_UP
#   KUBE_TEMP
#   KUBE_ROOT
#   FLANNEL_NET
#   FLANNEL_SUBNET_LEN
#   FLANNEL_SUBNET_MIN
#   FLANNEL_SUBNET_MAX
#   FLANNEL_TYPE
#   CLUSTER_NAME
#   ADMISSION_CONTROL
#   CAICLOUD_PROVIDER
#   POD_INFRA_CONTAINER
#   KUBERNETES_PROVIDER
#   MASTER_SSH_EXTERNAL
#   PRIVATE_SDN_INTERFACE
#   SERVICE_CLUSTER_IP_RANGE
function send-master-files {
  # Randomly choose one daocloud accelerator.
  find-registry-mirror

  # PRIVATE_SDN_INTERFACE is used as the interface for flanneld to send
  # internal traffic. If not set, master internal IP address will be used.
  if [[ "${PRIVATE_SDN_INTERFACE:-}" != "" ]]; then
    interface="${PRIVATE_SDN_INTERFACE}"
  else
    IFS=':@' read -ra ssh_info <<< "${MASTER_SSH_EXTERNAL}"
    interface="${ssh_info[2]}"
  fi

  # All files will be stored under this directory.
  mkdir -p ${KUBE_TEMP}/kube-master/kube/master

  # Script to bring up master.
  (
    echo "#!/bin/bash"
    echo ""
    # Pass environment variables to startup script as configuration.
    echo "ADMISSION_CONTROL=${ADMISSION_CONTROL}"
    echo "CAICLOUD_PROVIDER=${CAICLOUD_PROVIDER}"
    echo "CLUSTER_NAME=${CLUSTER_NAME}"
    echo "DNS_DOMAIN=${DNS_DOMAIN}"
    echo "DNS_SERVER_IP=${DNS_SERVER_IP}"
    echo "FLANNEL_INTERFACE=${interface}"
    echo "FLANNEL_NET=${FLANNEL_NET}"
    echo "FLANNEL_SUBNET_LEN=${FLANNEL_SUBNET_LEN}"
    echo "FLANNEL_SUBNET_MIN=${FLANNEL_SUBNET_MIN}"
    echo "FLANNEL_SUBNET_MAX=${FLANNEL_SUBNET_MAX}"
    echo "FLANNEL_TYPE=${FLANNEL_TYPE}"
    echo "KUBELET_IP_ADDRESS=${KUBELET_IP_ADDRESS}"
    echo "MASTER_SECURE_ADDRESS=${MASTER_SECURE_ADDRESS}"
    echo "MASTER_INSECURE_ADDRESS=${MASTER_INSECURE_ADDRESS}"
    echo "MASTER_INSECURE_PORT=${MASTER_INSECURE_PORT}"
    echo "MASTER_SSH_INFO=${MASTER_SSH_INFO:-}"
    echo "NODE_SSH_INFO=${NODE_SSH_INFO:-}"
    echo "POD_INFRA_CONTAINER=${POD_INFRA_CONTAINER}"
    echo "REGISTER_MASTER_KUBELET=${REGISTER_MASTER_KUBELET}"
    echo "REGISTRY_MIRROR=${REGISTRY_MIRROR}"
    echo "SERVICE_CLUSTER_IP_RANGE=${SERVICE_CLUSTER_IP_RANGE}"
    echo "USE_SELF_SIGNED_CERT=${USE_SELF_SIGNED_CERT}"
    echo ""
    grep -v "^#" "${KUBE_ROOT}/cluster/caicloud/config-components.sh"
    grep -v "^#" "${KUBE_ROOT}/cluster/${KUBERNETES_PROVIDER}/config-default.sh"
    echo ""
    echo "mkdir -p ~/kube/configs"
    # The following create-*-opts functions create component options (flags).
    # The flag options are stored under ~/kube/configs.
    echo "create-etcd-opts"
    echo "create-kube-apiserver-opts"
    echo "create-kube-scheduler-opts"
    echo "create-kube-controller-manager-opts"
    echo "create-kubelet-opts    'master'"
    echo "create-kube-proxy-opts 'master'"
    echo "create-flanneld-opts   'master'"
    # Create the system directories used to hold the final data.
    echo "sudo mkdir -p /opt/bin"
    echo "sudo mkdir -p /etc/kubernetes"
    echo "sudo mkdir -p /etc/kubernetes/manifest"
    # Since we might retry on error during kube-up, we need to stop services.
    # If no service is running, this is just no-op.
    echo "sudo service etcd stop"
    # Copy binaries and configurations to system directories.
    echo "sudo cp ~/kube/master/* /opt/bin"
    echo "sudo cp ~/kube/configs/* /etc/default"
    echo "sudo cp ~/kube/init_conf/* /etc/init/"
    echo "sudo cp ~/kube/init_scripts/* /etc/init.d/"
    if [[ "${ENABLE_CLUSTER_LOGGING}" == "true" ]]; then
      echo "sudo cp ~/kube/fluentd-es.yaml /etc/kubernetes/manifest"
    fi
    if [[ "${ENABLE_CLUSTER_REGISTRY}" == "true" ]]; then
      echo "sudo cp ~/kube/registry-proxy.yaml /etc/kubernetes/manifest"
    fi
    if [[ "${USE_SELF_SIGNED_CERT}" == "false" ]]; then
      echo "sudo mkdir -p /etc/kubernetes/nginx"
      echo "sudo cp ~/kube/nginx.yaml /etc/kubernetes/manifest"
      echo "sudo cp ~/kube/nginx.conf /etc/kubernetes/nginx"
    fi
    if [[ "${KUBE_UP}" == "Y" ]]; then
      echo "sudo cp ~/kube/kubelet-kubeconfig ~/kube/kube-proxy-kubeconfig /etc/kubernetes"
      echo "sudo cp ~/kube/known-tokens.csv ~/kube/basic-auth.csv /etc/kubernetes"
      echo "sudo cp ~/kube/certs/ca.crt ~/kube/certs/master.crt ~/kube/certs/master.key /etc/kubernetes"
      if [[ "${USE_SELF_SIGNED_CERT}" == "false" ]]; then
        echo "sudo cp -r ~/kube/certs/caicloudapp_certs /etc/kubernetes"
      fi
    fi
    # Make sure cloud-config exists, even if not used.
    echo "touch ~/kube/cloud-config && sudo cp ~/kube/cloud-config /etc/kubernetes"
    # Credential used to pull images from index.caicloud.io (kubelet credentialprovider).
    echo "sudo mkdir -p /var/lib/kubelet && sudo cp ~/kube/docker-config.json /var/lib/kubelet/config.json"
    # Remove rwx permission on folders we don't want user to mess up with.
    echo "sudo chmod go-rwx /etc/kubernetes"
    # Finally, start kubernetes cluster. Upstart will make sure all components
    # start upon etcd start.
    echo "sudo service etcd start"
    # After starting etcd, configure flannel options.
    echo "config-etcd-flanneld"
    # After starting flannel, configure docker network to use flannel overlay.
    echo "restart-docker /etc/default/docker"
  ) > ${KUBE_TEMP}/kube-master/kube/master-start.sh
  chmod a+x ${KUBE_TEMP}/kube-master/kube/master-start.sh

  # Script to clean up master.
  (
    echo "#!/bin/bash"
    echo "sudo service etcd stop"
    echo "sudo rm -rf ~/kube /var/run/flannel /run/flannel"
    echo "sudo rm -rf /kubernetes-master.etcd"
    echo "sudo rm -rf /opt/bin/kube* /opt/bin/flanneld /opt/bin/etcd*"
  ) > ${KUBE_TEMP}/kube-master/kube/master-cleanup.sh
  chmod a+x ${KUBE_TEMP}/kube-master/kube/master-cleanup.sh

  local -r nginx_conf_file="${KUBE_ROOT}/cluster/caicloud/addons/nginx/nginx.conf.in"
  sed -e "s/{{ pillar\['master_secure_location'\] }}/${MASTER_SECURE_ADDRESS}/g" ${nginx_conf_file} > ${KUBE_TEMP}/nginx.conf
  cp -r ${KUBE_ROOT}/cluster/caicloud/trusty/master/init_conf \
     ${KUBE_ROOT}/cluster/caicloud/trusty/master/init_scripts \
     ${KUBE_ROOT}/cluster/caicloud/trusty/manifest/fluentd-es.yaml \
     ${KUBE_ROOT}/cluster/caicloud/trusty/manifest/registry-proxy.yaml \
     ${KUBE_ROOT}/cluster/caicloud/trusty/manifest/nginx.yaml \
     ${KUBE_ROOT}/cluster/caicloud/tools/docker-config.json \
     ${KUBE_TEMP}/nginx.conf \
     ${KUBE_TEMP}/kube-master/kube
  if [[ "${KUBE_UP}" == "Y" ]]; then
    cp -r ${KUBE_ROOT}/cluster/caicloud/trusty/master/init_conf \
       ${KUBE_TEMP}/known-tokens.csv \
       ${KUBE_TEMP}/basic-auth.csv \
       ${KUBE_TEMP}/certs \
       ${KUBE_TEMP}/kubelet-kubeconfig \
       ${KUBE_TEMP}/kube-proxy-kubeconfig \
       ${KUBE_TEMP}/kube-master/kube
  fi
  if [[ "${CAICLOUD_PROVIDER:-}" != "" ]]; then
    cp ${KUBE_TEMP}/cloud-config ${KUBE_TEMP}/kube-master/kube/cloud-config
  fi
  scp-to-instance-expect "${MASTER_SSH_EXTERNAL}" "${KUBE_TEMP}/kube-master/kube" "~"
  ssh-to-instance-expect "${MASTER_SSH_EXTERNAL}" "\
sudo mkdir -p /etc/caicloud && sudo cp ~/kube/kubelet-kubeconfig ~/kube/kube-proxy-kubeconfig /etc/caicloud"
}

# Create node scripts and config files, then send to nodes.
#
# Assumed vars:
#   KUBE_TEMP
#   KUBE_ROOT
#   DNS_DOMAIN
#   DNS_SERVER_IP
#   KUBELET_IP_ADDRESS
#   PRIVATE_SDN_INTERFACE
#   POD_INFRA_CONTAINER
#   REGISTRY_MIRROR
#   MASTER_SSH_EXTERNAL
#   CAICLOUD_PROVIDER
#   NODE_SSH_EXTERNAL
#   NODE_INSTANCE_IDS
function send-node-files {
  # Randomly choose one daocloud accelerator.
  find-registry-mirror

  # Get array of hostnames to override if necessary.
  if [[ "${NODE_INSTANCE_IDS:-}" != "" ]]; then
    IFS=',' read -ra hostname_arr <<< "${NODE_INSTANCE_IDS}"
  fi

  local pids=""
  IFS=',' read -ra node_ssh_info <<< "${NODE_SSH_EXTERNAL}"
  for (( i = 0; i < ${#node_ssh_info[*]}; i++ )); do
    if [[ "${PRIVATE_SDN_INTERFACE:-}" != "" ]]; then
      interface="${PRIVATE_SDN_INTERFACE}"
    else
      IFS=':@' read -ra ssh_info <<< "${node_ssh_info[$i]}"
      interface="${ssh_info[2]}"
    fi
    if [[ "${NODE_INSTANCE_IDS:-}" != "" ]]; then
      hostname_override="${hostname_arr[$i]}"
    else
      hostname_override=""
    fi
    send-node-files-internal "${node_ssh_info[$i]}" "${interface}" "${hostname_override}" & pids="${pids} $!"
  done
  wait ${pids}
}
# Input:
#   $1 Node ssh info, e.g. "root:password@43.254.54.59"
#   $2 Interface or IP address used by flanneld to send internal traffic.
#   $3 Hostname override
function send-node-files-internal {
  mkdir -p ${KUBE_TEMP}/kube-node${1}/kube/node

  # Create node startup script. Note we assume the os has necessary tools
  # installed, e.g. docker, bridge-util, etc. The flow is similar to master
  # startup script.
  (
    echo "#!/bin/bash"
    echo ""
    # Pass environment variables to startup script as configuration.
    echo "ADMISSION_CONTROL=${ADMISSION_CONTROL}"
    echo "CAICLOUD_PROVIDER=${CAICLOUD_PROVIDER}"
    echo "CLUSTER_NAME=${CLUSTER_NAME}"
    echo "DNS_DOMAIN=${DNS_DOMAIN}"
    echo "DNS_SERVER_IP=${DNS_SERVER_IP}"
    echo "FLANNEL_INTERFACE=${2}"
    echo "KUBELET_IP_ADDRESS=${KUBELET_IP_ADDRESS}"
    echo "MASTER_SECURE_ADDRESS=${MASTER_SECURE_ADDRESS}"
    echo "MASTER_INSECURE_ADDRESS=${MASTER_INSECURE_ADDRESS}"
    echo "MASTER_INSECURE_PORT=${MASTER_INSECURE_PORT}"
    echo "MASTER_SSH_INFO=${MASTER_SSH_INFO:-}"
    echo "NODE_SSH_INFO=${NODE_SSH_INFO:-}"
    echo "POD_INFRA_CONTAINER=${POD_INFRA_CONTAINER}"
    echo "REGISTER_MASTER_KUBELET=${REGISTER_MASTER_KUBELET}"
    echo "REGISTRY_MIRROR=${REGISTRY_MIRROR}"
    echo "SERVICE_CLUSTER_IP_RANGE=${SERVICE_CLUSTER_IP_RANGE}"
    echo "USE_SELF_SIGNED_CERT=${USE_SELF_SIGNED_CERT}"
    echo ""
    grep -v "^#" "${KUBE_ROOT}/cluster/caicloud/config-components.sh"
    grep -v "^#" "${KUBE_ROOT}/cluster/${KUBERNETES_PROVIDER}/config-default.sh"
    echo ""
    echo "mkdir -p ~/kube/configs"
    # Create component options.
    echo "create-kubelet-opts    'node' ${3}"
    echo "create-kube-proxy-opts 'node'"
    echo "create-flanneld-opts   'node'"
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
    if [[ "${ENABLE_CLUSTER_LOGGING}" == "true" ]]; then
      echo "sudo cp ~/kube/fluentd-es.yaml /etc/kubernetes/manifest"
    fi
    if [[ "${ENABLE_CLUSTER_REGISTRY}" == "true" ]]; then
      echo "sudo cp ~/kube/registry-proxy.yaml /etc/kubernetes/manifest"
    fi
    # Credential used to pull images from index.caicloud.io (kubelet credentialprovider).
    echo "sudo mkdir -p /var/lib/kubelet && sudo cp ~/kube/docker-config.json /var/lib/kubelet/config.json"
    echo "sudo cp ~/kube/kubelet-kubeconfig ~/kube/kube-proxy-kubeconfig /etc/kubernetes"
    # Make sure cloud-config exists, even if not used.
    echo "touch ~/kube/cloud-config && sudo cp ~/kube/cloud-config /etc/kubernetes"
    # Finally, start kubernetes cluster. Upstart will make sure all components
    # start upon flannel start.
    echo "sudo service flanneld start"
    # After starting flannel, configure docker network to use flannel overlay.
    echo "restart-docker /etc/default/docker"
  ) > ${KUBE_TEMP}/kube-node${1}/kube/node-start.sh
  chmod a+x ${KUBE_TEMP}/kube-node${1}/kube/node-start.sh

  # Script to clean up node.
  (
    echo "#!/bin/bash"
    echo "sudo service flanneld stop"
    echo "sudo rm -rf ~/kube /var/run/flannel /run/flannel"
    echo "sudo rm -rf /opt/bin/kube* /opt/bin/flanneld /opt/bin/etcd*"
  ) > ${KUBE_TEMP}/kube-node${1}/kube/node-cleanup.sh
  chmod a+x ${KUBE_TEMP}/kube-node${1}/kube/node-cleanup.sh

  cp -r ${KUBE_ROOT}/cluster/caicloud/trusty/node/init_conf \
     ${KUBE_ROOT}/cluster/caicloud/trusty/node/init_scripts \
     ${KUBE_ROOT}/cluster/caicloud/trusty/manifest/fluentd-es.yaml \
     ${KUBE_ROOT}/cluster/caicloud/trusty/manifest/registry-proxy.yaml \
     ${KUBE_ROOT}/cluster/caicloud/tools/nsenter \
     ${KUBE_ROOT}/cluster/caicloud/tools/docker-config.json \
     ${KUBE_TEMP}/kube-node${1}/kube

  if [[ "${CAICLOUD_PROVIDER:-}" != "" ]]; then
    cp ${KUBE_TEMP}/cloud-config ${KUBE_TEMP}/kube-node${1}/kube/cloud-config
  fi
  scp-to-instance-expect "${1}" "${KUBE_TEMP}/kube-node${1}/kube" "~"

  # Fetch kubelet-kubeconfig & kube-proxy-kubeconfig from master
  IFS=':@' read -ra master_ssh_info <<< "${MASTER_SSH_EXTERNAL}"
  IFS=':@' read -ra ssh_info <<< "${1}"
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

# Install packages for all instances. The packages are required for running
# kubernetes nodes.
#
# Input:
#   $1 report failure; if true, report failure to caicloud cluster manager.
#
# Assumed vars:
#   INSTANCE_SSH_EXTERNAL
#   APT_MIRRORS
#   KUBE_INSTANCE_LOGDIR
function install-packages {
  APT_MIRROR_INDEX=0            # Used for choosing an apt mirror.
  command-exec-and-retry "install-packages-internal" 2 "${1:-}"
}
function install-packages-internal {
  log "+++++ Start installing packages."

  # Choose an apt-mirror for installing packages.
  IFS=',' read -ra apt_mirror_arr <<< "${APT_MIRRORS}"
  apt_mirror=${apt_mirror_arr[$(( ${APT_MIRROR_INDEX} % ${#apt_mirror_arr[*]} ))]}
  APT_MIRROR_INDEX=$(($APT_MIRROR_INDEX+1))
  log "Use apt mirror ${apt_mirror}"

  # Install packages for given instances concurrently.
  local pids=""
  IFS=',' read -ra instance_ssh_info <<< "${INSTANCE_SSH_EXTERNAL}"
  for ssh_info in "${instance_ssh_info[@]}"; do
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
sudo apt-get update
sudo apt-get install --allow-unauthenticated -y docker-engine=${DOCKER_VERSION}-0~trusty && \
sudo apt-get install bridge-utils socat || \
echo 'Command failed installing packages on remote host ${ssh_info[2]}'"

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
# contact kubelet using hostname. This is used in baremetal and cloudproviders that
# do not support hostname resolution between instances.
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
