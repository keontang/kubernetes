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

set -e

# Release version for creating cluster.
ETCD_VERSION="v2.0.9"
FLANNEL_VERSION="0.4.0"
K8S_VERSION="v0.18.2"

# When running dev, time constraint operations will be ignored, e.g. copying binary.
DEV_MODE=false

# Helper constants.
ANCHNET_CMD="anchnet"


# Step1 of cluster bootstrapping: verify cluster prerequisites.
function verify-prereqs {
  if [[ "$(which anchnet)" == "" ]]; then
    echo "Can't find anchnet cli binary in PATH, please fix and retry."
    echo "See https://github.com/caicloud/anchnet-go/tree/master/anchnet"
    exit 1
  fi
  if [[ "$(which expect)" == "" ]]; then
    echo "Can't find expect binary in PATH, please fix and retry."
    echo "For ubuntu, if you have root access, run: sudo apt-get install expect."
    exit 1
  fi
  if [[ ! -f ~/.ssh/id_rsa.pub ]]; then
    echo "Can't find id_rsa.pub in ~/.ssh, please fix and retry."
    echo "For linux, run `ssh-keygen -t rsa` to create one."
    exit 1
  fi
}

# Step2 of cluster bootstrapping: create all machines and provision them.
function kube-up {
  # For dev, use a constant password.
  if [[ "${DEV_MODE}" = true ]]; then
    KUBE_INSTANCE_PASSWORD="caicloud2015ABC"
  else
    # Get KUBE_INSTANCE_PASSWORD which will be used to login into anchnet instances.
    prompt-instance-password
  fi

  # For dev, set temp path directly to avoid constantly download.
  if [[ "${DEV_MODE}" = true ]]; then
    KUBE_TEMP=/tmp/kubernetes.EuWJ4M
  else
    # Download release to a temporary directory KUBE_TEMP.
    # TODO: Better to use a fixed path for releases on our deploy machine.
    ensure-temp-dir
    download-release
  fi

  # Get all cluster configuration parameters.
  KUBE_ROOT="$(dirname "${BASH_SOURCE}")/../.."
  source "${KUBE_ROOT}/cluster/anchnet/config-default.sh"

  # For dev, set to existing machine.
  if [[ "${DEV_MODE}" = true ]]; then
    MASTER_INSTANCE_ID="i-J4I8MLUM"
    MASTER_EIP_ID="eip-ENLTSZAK"
    MASTER_EIP="43.254.53.31"
    NODE_INSTANCE_IDS="i-D1RKLR3I,i-YN56DOZC"
    NODE_EIP_IDS="eip-ZNOD789N,eip-BHPI0MQY"
    NODE_EIPS="43.254.53.191,43.254.53.76"
    PRIVATE_INTERFACE="eth1"
  else
    # Create master/node instances from anchnet without provision. The following
    # two methods will create a set of vars to be used later.
    #   MASTER_INSTANCE_ID,  MASTER_EIP_ID,  MASTER_EIP
    #   NODE_INSTANCE_IDS, NODE_EIP_IDS, NODE_EIPS
    # TODO: The process can run concurrently to speed up bootstrapping.
    # TODO: Firewall setup, need a method create-firewall.
    create-master-instance
    create-node-instances
    # Create a private SDN. Add master, nodes to it. The IP addresses of the
    # machines are determined from INSTANCE_IP_RANGE, e.g. 10.244.0.0/16
    create-sdn-network
  fi

  # Now start provisioning master and nodes.
  create-etcd-initial-cluster
  provision-master
  provision-nodes

  # Create a username/password for accessing cluster. KUBE_MASTER_IP
  # and CONTEXT are used in create-kubeconfig
  source "${KUBE_ROOT}/cluster/common.sh"
  KUBE_MASTER_IP="${MASTER_EIP}"
  CONTEXT="anchnet_kubernetes"
  get-password
  create-kubeconfig
}

# Step3 of cluster bootstrapping: verify cluster is up.
function verify-cluster {
  echo "Delegate verifying cluster to deployment manager"
}

# Ask for a password which will be used for all instances.
#
# Vars set:
#   KUBE_INSTANCE_PASSWORD
function prompt-instance-password {
  read -s -p "Please enter password for new instances: " KUBE_INSTANCE_PASSWORD
  echo
  read -s -p "Password (again): " another
  echo
  if [[ "${KUBE_INSTANCE_PASSWORD}" != "${another}" ]]; then
    echo "Passwords do not match"
    exit 1
  fi
}

# Ensure that we have a password created for validating to the master.
#
# Vars set:
#   KUBE_USER
#   KUBE_PASSWORD
function get-password {
  if [[ -z ${KUBE_USER-} || -z ${KUBE_PASSWORD-} ]]; then
    KUBE_USER=admin
    KUBE_PASSWORD=$(python -c 'import string,random; print "".join(random.SystemRandom().choice(string.ascii_letters + string.digits) for _ in range(16))')
  fi
}

# Create a temporary directory that'll be deleted at the end of this bash session.
#
# Vars set:
#   KUBE_TEMP
function ensure-temp-dir {
  if [[ -z ${KUBE_TEMP-} ]]; then
    KUBE_TEMP=$(mktemp -d -t kubernetes.XXXXXX)
    trap 'rm -rf "${KUBE_TEMP}"' EXIT
  fi
}

# Evaluate a json string and return required fields
function json_val {
  python -c 'import json,sys;obj=json.load(sys.stdin);print obj'$1''
}

# Download release to a temp dir, organized by master and node. E.g.
#  /tmp/kubernetes.EuWJ4M/master
#  /tmp/kubernetes.EuWJ4M/node
#
# TODO: We should host our own release (or better yet, create base image), to speed up cluster bootstrap.
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

# Create a single master instance from anchnet.
#
# TODO: Investigate HA master setup.
#
# Assumed vars:
#   KUBE_ROOT
#   KUBE_TEMP
#   KUBE_INSTANCE_PASSWORD
#
# Vars set:
#   MASTER_INSTANCE_ID
#   MASTER_EIP_ID
#   MASTER_EIP
function create-master-instance {
  echo "+++++ Creating kubernetes master from anchnet"

  # Example return value for master_info
  # '{"action":"RunInstancesResponse","ret_code":0,"instances":["i-9E29CAYQ"],"eips":["eip-HII6N9DU"],"job_id":"job-391ZX30X"}'
  local master_info=$(${ANCHNET_CMD} runinstance master -p="${KUBE_INSTANCE_PASSWORD}")
  MASTER_INSTANCE_ID=$(echo ${master_info} | json_val '["instances"][0]')
  MASTER_EIP_ID=$(echo ${master_info} | json_val '["eips"][0]')

  # Create a 'raw' master instance from anchnet, i.e. un-provisioned.
  check-instance-status "${MASTER_INSTANCE_ID}"
  get-ip-address-from-eipid "${MASTER_EIP_ID}"
  MASTER_EIP=${EIP_ADDRESS}

  # Enable ssh without password.
  setup-instance-ssh "${MASTER_EIP}"

  echo "Created master with instance ID ${MASTER_INSTANCE_ID}, eip ID ${MASTER_EIP_ID}, master eip: ${MASTER_EIP}"
}

# Create node instances from anchnet.
#
# TODO: Investigate creating node without external IPs
#
# Assumed vars:
#   NUM_MINIONS
#
# Vars set:
#   NODE_INSTANCE_IDS - comma separated string of instance IDs
#   NODE_EIP_IDS - comma separated string of instance external IP IDs
#   NODE_EIPS - comma separated string of instance external IPs
function create-node-instances {
  for (( i=0; i<${NUM_MINIONS}; i++)); do
    echo "+++++ Creating kubernetes node-${i} from anchnet"
    local node_info=$(${ANCHNET_CMD} runinstance node-${i} -p="${KUBE_INSTANCE_PASSWORD}")
    local node_instance_id=$(echo ${node_info} | json_val '["instances"][0]')
    local node_eip_id=$(echo ${node_info} | json_val '["eips"][0]')

    # Create a 'raw' node instance from anchnet, i.e. un-provisioned.
    check-instance-status "${node_instance_id}"
    get-ip-address-from-eipid "${node_eip_id}"
    local node_eip=${EIP_ADDRESS}
    echo "Created node-${i} with instance ID ${node_instance_id}, eip ID ${node_eip_id}. Node EIP: ${node_eip}"

    # Enable ssh without password.
    setup-instance-ssh "${node_eip}"

    # Set output vars. Note we use ${NODE_EIPS-} to check if NODE_EIPS is unset,
    # as toplevel script set -o nounset
    if [[ -z "${NODE_EIPS-}" ]]; then
      NODE_INSTANCE_IDS="${node_instance_id}"
      NODE_EIP_IDS="${node_eip_id}"
      NODE_EIPS="${node_eip}"
    else
      NODE_INSTANCE_IDS="${NODE_INSTANCE_IDS},${node_instance_id}"
      NODE_EIP_IDS="${NODE_EIP_IDS},${node_eip_id}"
      NODE_EIPS="${NODE_EIPS},${node_eip}"
    fi
  done

  echo "Created cluster nodes with instance IDs ${NODE_INSTANCE_IDS}, eip IDs ${NODE_EIP_IDS}, node eips ${NODE_EIPS}"
}

# Check instance status from anchnet, break out until it's in running status.
#
# Input:
#   Instance ID, e.g. i-TRMTHPWG
function check-instance-status {
  local attempt=0
  while true; do
    echo "Attempt $(($attempt+1)) to check for instance running"
    local status=$(${ANCHNET_CMD} describeinstance $1 | json_val '["item_set"][0]["status"]')
    if [[ ${status} != "running" ]]; then
      if (( attempt > 30 )); then
        echo
        echo -e "${color_red}Instance $1 failed to start (sorry!)${color_norm}" >&2
        exit 1
      fi
    else
      echo "Instance $1 becomes running status"
      break
    fi
    attempt=$(($attempt+1))
    sleep 10
  done
}

# Get Eip IP address from EIP ID. Ideally, we don't need this since we can get
# IP address from instance itself, but anchnet API is not stable. It sometimes
# returns empty string, sometimes returns null.
#
# Input:
#   Eip ID, e.g. eip-TRMTHPWG
#
# Output:
#   EIP_ADDRESS - The external IP address of the EIP
function get-ip-address-from-eipid {
  local attempt=0
  while true; do
    echo "Attempt $(($attempt+1)) to get eip"
    local eip=$(${ANCHNET_CMD} describeeips $1 | json_val '["item_set"][0]["eip_addr"]')
    # Test the return value roughly matches ipv4 format.
    if [[ ! ${eip} =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
      if (( attempt > 30 )); then
        echo
        echo -e "${color_red}failed to get eip address (sorry!)${color_norm}" >&2
        exit 1
      fi
    else
      echo "Get Eip address"
      EIP_ADDRESS=${eip}
      break
    fi
    attempt=$(($attempt+1))
    sleep 10
  done
}

# SSH to the machine and put the host's pub key to master's authorized_key,
# so future ssh commands do not require password to login. Note however,
# if ubuntu is used, then we still need 'expect' to enter password because
# root login is disabled by default in ubuntu.
#
# Input:
#   Instance external IP address
#
# Assumed vars:
#   KUBE_INSTANCE_PASSWORD
function setup-instance-ssh {
  # TODO: Maybe generate a new key pair here.
  # TODO: Use ubuntu image for now. If we use different image, user name can be 'root'.
  # Use a large timeout to tolerate ssh connection delay; otherwise, expect script will mess up.
  expect <<EOF
set timeout 120
spawn scp -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
  $HOME/.ssh/id_rsa.pub ubuntu@$1:~/host_rsa.pub
expect "*?assword:"
send -- "${KUBE_INSTANCE_PASSWORD}\r"
expect eof
spawn ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
  ubuntu@$1 "umask 077 && mkdir -p ~/.ssh && cat ~/host_rsa.pub >> ~/.ssh/authorized_keys && rm -rf ~/host_rsa.pub"
expect "*?assword:"
send -- "${KUBE_INSTANCE_PASSWORD}\r"
expect eof
EOF

  attempt=0
  while true; do
    echo -n "Attempt $(($attempt+1)) to check for SSH to instance $1"
    local output
    local ok=1
    output=$(ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet ubuntu@$1 uptime) || ok=0
    if [[ ${ok} == 0 ]]; then
      if (( attempt > 30 )); then
        echo
        echo -e "${color_red}Unable to ssh to instance on $1, output was ${output} (sorry!)${color_norm}" >&2
        exit 1
      fi
    else
      echo -e " ${color_green}[ssh to instance working]${color_norm}"
      break
    fi
    echo -e " ${color_yellow}[ssh to instance not working yet]${color_norm}"
    attempt=$(($attempt+1))
    sleep 5
  done
}

# Create a private SDN network in anchnet, then add master and nodes to it. Once
# done, all instances can be reached from preconfigured private IP address.
#
# Assumed vars:
#   VXNET_NAME
#
# Vars set:
#   PRIVATE_INTERFACE - The interface created by the SDN network
function create-sdn-network {
  # Create a private SDN network.
  local vxnet_info=$(${ANCHNET_CMD} createvxnets ${VXNET_NAME})
  VXNET_ID=$(echo ${vxnet_info} | json_val '["vxnets"][0]')
  # There is no easy way to determine if vxnet is created or not. Fortunately, we can
  # send command to describe vxnets, when return, we should have vxnet created.
  ${ANCHNET_CMD} describevxnets ${VXNET_ID} > /dev/null
  sleep 5                       # Some grace period

  # Add all instances (master and nodes) to the vxnet.
  ALL_INSTANCE_IDS="${MASTER_INSTANCE_ID},${NODE_INSTANCE_IDS}"
  ${ANCHNET_CMD} joinvxnet ${VXNET_ID} ${ALL_INSTANCE_IDS}
  # Wait for instances to be added successfully.
  ${ANCHNET_CMD} describevxnets ${VXNET_ID} > /dev/null
  sleep 5                       # Some grace period

  # TODO: This is almost always true in anchnet ubuntu image. We can do better using describevxnets.
  PRIVATE_INTERFACE="eth1"
}

# Create static etcd cluster.
#
# Assumed vars:
#   MASTER_INTERNAL_IP
#   NODE_INTERNAL_IPS
#
# Vars set:
#   ETCD_INITIAL_CLUSTER - variable supplied to etcd for static cluster discovery.
function create-etcd-initial-cluster {
  ETCD_INITIAL_CLUSTER="kubernetes-master=http://${MASTER_INTERNAL_IP}:2380"
  IFS=',' read -ra node_iip_arr <<< "${NODE_INTERNAL_IPS}"
  local i=0
  for node_internal_ip in "${node_iip_arr[@]}"; do
    ETCD_INITIAL_CLUSTER="$ETCD_INITIAL_CLUSTER,kubernetes-node${i}=http://${node_internal_ip}:2380"
    i=$(($i+1))
  done
}

# The method assumes master instance is running. It does the following two things:
# 1. Create a working directory (and its subdirectory) in master.
# 2. Copies master component binaries and their configs to the directory.
# 3. Create a master-start.sh file which applies the configs, setup network, and
#   starts k8s master.
#
# TODO: Copying binaries is too slow. Similar to download-release, we should host
#   our own release or create base image.
#
# Assumed vars:
#   KUBE_ROOT
#   KUBE_TEMP
#   MASTER_EIP
#   MASTER_INTERNAL_IP
#   ETCD_INITIAL_CLUSTER
#   SERVICE_CLUSTER_IP_RANGE
#   PRIVATE_INTERFACE
function provision-master {
  echo "+++++ Start provisioning master"

  # Create master startup script.
  (
    echo "#!/bin/bash"
    echo "mkdir -p ~/kube/default ~/kube/network"
    grep -v "^#" "${KUBE_ROOT}/cluster/anchnet/config-components.sh"
    grep -v "^#" "${KUBE_ROOT}/cluster/anchnet/config-default.sh"
    echo ""
    echo "create-etcd-opts kubernetes-master \"${MASTER_INTERNAL_IP}\" \"${ETCD_INITIAL_CLUSTER}\""
    echo "create-kube-apiserver-opts \"${SERVICE_CLUSTER_IP_RANGE}\""
    echo "create-kube-controller-manager-opts"
    echo "create-kube-scheduler-opts"
    echo "create-flanneld-opts ${PRIVATE_INTERFACE}"
    echo "create-private-interface-opts ${PRIVATE_INTERFACE} ${MASTER_INTERNAL_IP}"
    echo "sudo cp ~/kube/default/* /etc/default"
    echo "sudo cp ~/kube/init_conf/* /etc/init/"
    echo "sudo cp ~/kube/init_scripts/* /etc/init.d/"
    echo "sudo cp ~/kube/network/interfaces /etc/network/interfaces"
    echo "sudo mkdir -p /opt/bin && sudo cp ~/kube/master/* /opt/bin"
    echo "sudo sed -i 's/^managed=false/managed=true/' /etc/NetworkManager/NetworkManager.conf"
    echo "sudo service network-manager restart"
    # This is tricky. k8s uses /proc/net/route to find public interface; if we do not sleep here,
    # the network-manager hasn't finished bootstrap and the routing table in /proc won't be established.
    # So k8s (e.g. api-server) will bailout and complains no interface to bind.
    echo "sleep 10"
    echo "sudo service etcd start"
  ) > "${KUBE_TEMP}/master-start.sh"
  chmod a+x ${KUBE_TEMP}/master-start.sh

  # Create a working directory on master instance.
  ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
      "ubuntu@${MASTER_EIP}" "mkdir -p ~/kube"
  # Copy master component binaries, configurations and startup script to master instance.
  # For dev, do not copy binary.
  if [[ "${DEV_MODE}" = false ]]; then
    scp -r -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
        ${KUBE_TEMP}/master "ubuntu@${MASTER_EIP}":~/kube
  fi
  scp -r -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
      ${KUBE_ROOT}/cluster/anchnet/master/* \
      ${KUBE_TEMP}/master-start.sh \
      "ubuntu@${MASTER_EIP}":~/kube
  # TODO: call master-start.sh to start master.
}

# The method assumes node instances are running. It does the similar thing as
# provision-master, but to nodes.
#
# TODO: Create caicloud registry to host images like caicloud/k8s-pause:0.8.0.
#
# Assumed vars:
#   KUBE_ROOT
#   KUBE_TEMP
#   NODE_EIPS
#   NODE_INTERNAL_IPS
#   ETCD_INITIAL_CLUSTER
#   DNS_SERVER_IP
#   DNS_DOMAIN
#   POD_INFRA_CONTAINER
function provision-nodes {
  local i=0
  IFS=',' read -ra node_iip_arr <<< "${NODE_INTERNAL_IPS}"
  IFS=',' read -ra node_eip_arr <<< "${NODE_EIPS}"

  for node_internal_ip in "${node_iip_arr[@]}"; do
    echo "+++++ Start provisioning node-${i}"
    local node_eip=${node_eip_arr[${i}]}
    # TODO: In 'create-kubelet-opts', we use ${node_internal_ip} as kubelet host
    #   override due to lack of cloudprovider support. This essentially means that
    #   k8s is running as a bare-metal cluster. Once we implement that interface,
    #   we have a full-fleged k8s running on anchnet.
    # Create node startup script.
    (
      echo "#!/bin/bash"
      echo "mkdir -p ~/kube/default ~/kube/network"
      grep -v "^#" "${KUBE_ROOT}/cluster/anchnet/config-components.sh"
      grep -v "^#" "${KUBE_ROOT}/cluster/anchnet/config-default.sh"
      grep -v "^#" "${KUBE_ROOT}/cluster/anchnet/reconf-docker.sh"
      echo ""
      echo "create-etcd-opts kubernetes-node${i} \"${node_internal_ip}\" \"${ETCD_INITIAL_CLUSTER}\""
      echo "create-kubelet-opts ${node_internal_ip} \"${MASTER_INTERNAL_IP}\" \"${DNS_SERVER_IP}\" \"${DNS_DOMAIN}\" \"${POD_INFRA_CONTAINER}\""
      echo "create-kube-proxy-opts \"${MASTER_INTERNAL_IP}\""
      echo "create-flanneld-opts ${PRIVATE_INTERFACE}"
      echo "create-private-interface-opts ${PRIVATE_INTERFACE} ${node_internal_ip}"
      # For dev, do not install node (docker, etc).
      if [[ "${DEV_MODE}" = false ]]; then
        echo "install-node"
      fi
      echo "sudo cp ~/kube/default/* /etc/default"
      echo "sudo cp ~/kube/init_conf/* /etc/init/"
      echo "sudo cp ~/kube/init_scripts/* /etc/init.d/"
      echo "sudo cp ~/kube/network/interfaces /etc/network/interfaces"
      echo "sudo mkdir -p /opt/bin && sudo cp ~/kube/node/* /opt/bin"
      echo "sudo sed -i 's/^managed=false/managed=true/' /etc/NetworkManager/NetworkManager.conf"
      echo "sudo service network-manager restart"
      # This is tricky. k8s uses /proc/net/route to find public interface; if we do not sleep here,
      # the network-manager hasn't finished bootstrap and the routing table in /proc won't be established.
      # So k8s (e.g. kube-proxy) will bailout and complains no interface to bind.
      echo "sleep 10"
      echo "sudo service etcd start"
      echo "reconfig-docker-net"
    ) > "${KUBE_TEMP}/node${i}-start.sh"
    chmod a+x ${KUBE_TEMP}/node${i}-start.sh

    # Create a working directory on node instance.
    ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
        "ubuntu@${node_eip}" "mkdir -p ~/kube"
    # Copy node component binaries, configurations and startup script to node instance.
    # For dev, do not copy binary.
    if [[ "${DEV_MODE}" = false ]]; then
      scp -r -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
          ${KUBE_TEMP}/node "ubuntu@${node_eip}":~/kube
    fi
    scp -r -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
        ${KUBE_ROOT}/cluster/anchnet/node/* \
        ${KUBE_TEMP}/node${i}-start.sh \
        "ubuntu@${node_eip}":~/kube
    i=$(($i+1))
    # TODO: call node${i}-start.sh to start node.
  done
}
