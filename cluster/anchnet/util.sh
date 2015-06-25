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

# When running dev, no machine will be created. Developer is responsible to
# specify the instance IDs, eip IDs, etc.
# TODO: Create a clean up script to stop all services, delete old configs, etc.
DEV_MODE=false

# The base image used to create master and node instance. This image is created
# from build-image.sh, which installs caicloud-k8s release binaries, docker, etc.
# This approach avoids downloading/installing when bootstrapping a cluster, which
# saves a lot of time. The image must be created from ubuntu, and has:
#   ~/kube/master - Directory containing all master binaries
#   ~/kube/node - Directory containing all node binaries
#   Installed docker
#   Installed bridge-utils
INSTANCE_IMAGE="img-EBYD687W"

# Helper constants.
ANCHNET_CMD="anchnet"


# Step1 of cluster bootstrapping: verify cluster prerequisites.
function verify-prereqs {
  if [[ "$(which ${ANCHNET_CMD})" == "" ]]; then
    echo "Can't find anchnet cli binary in PATH, please fix and retry."
    echo "See https://github.com/caicloud/anchnet-go/tree/master/anchnet"
    exit 1
  fi
  if [[ "$(which expect)" == "" ]]; then
    echo "Can't find expect binary in PATH, please fix and retry."
    echo "For ubuntu, if you have root access, run: sudo apt-get install expect."
    exit 1
  fi
}


# Step2 of cluster bootstrapping: create all machines and provision them.
function kube-up {
  # For dev, use a constant password.
  if [[ "${DEV_MODE}" = true ]]; then
    KUBE_INSTANCE_PASSWORD="caicloud2015ABC"
  else
    # Create KUBE_INSTANCE_PASSWORD, which will be used to login into anchnet instances.
    prompt-instance-password
  fi

  # Make sure we have a staging area.
  ensure-temp-dir

  # Make sure we have a public/private key pair used to provision the machine.
  ensure-pub-key

  # Get all cluster configuration parameters from config-default.
  KUBE_ROOT="$(dirname "${BASH_SOURCE}")/../.."
  source "${KUBE_ROOT}/cluster/anchnet/config-default.sh"

  # For dev, set to existing machine.
  if [[ "${DEV_MODE}" = true ]]; then
    MASTER_INSTANCE_ID="i-R9L16LW2"
    MASTER_EIP_ID="eip-3AF1DJM3"
    MASTER_EIP="43.254.55.115"
    NODE_INSTANCE_IDS="i-G6LUDOG0,i-WZ1TVLUY"
    NODE_EIP_IDS="eip-353TW9G4,eip-K613022N"
    NODE_EIPS="43.254.55.114,43.254.55.117"
    PRIVATE_INTERFACE="eth1"
  else
    # Create master/node instances from anchnet without provision. The following
    # two methods will create a set of vars to be used later:
    #   MASTER_INSTANCE_ID,  MASTER_EIP_ID,  MASTER_EIP
    #   NODE_INSTANCE_IDS,   NODE_EIP_IDS,   NODE_EIPS
    # TODO: The process can run concurrently to speed up bootstrapping.
    # TODO: Firewall setup, need a method create-firewall.
    create-master-instance
    create-node-instances
    # Create a private SDN. Add master, nodes to it. The IP address of the machines
    # in this network are based on MASTER_INTERNAL_IP and NODE_INTERNAL_IPS. The
    # method will create one var:
    #   PRIVATE_INTERFACE
    create-sdn-network
  fi

  # Create certificates and credentials to secure cluster communication.
  create-certs-and-credentials
  create-etcd-initial-cluster

  # Now start provisioning master and nodes.
  provision-master
  provision-nodes

  # common.sh defines create-kubeconfig, which is used to create client kubeconfig
  # for kubectl. To properly create kubeconfig, make sure to supply it with assumed
  # vars.
  # TODO: Fix hardcoded port in KUBE_MASTER_IP
  # TODO: Fix hardcoded CONTEXT
  source "${KUBE_ROOT}/cluster/common.sh"
  KUBE_MASTER_IP="${MASTER_EIP}:6443"
  CONTEXT="anchnet_kubernetes"
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


# Create ~/.ssh/id_rsa.pub if it doesn't exist.
function ensure-pub-key {
  if [[ ! -f ~/.ssh/id_rsa.pub ]]; then
    expect <<EOF
spawn ssh-keygen -t rsa -b 4096
expect "*rsa key*"
expect "*file in which to save the key*"
send -- "\r"
expect "*assphrase*"
send -- "\r"
expect "*assphrase*"
send -- "\r"
expect eof
EOF
  fi
}


# Ensure that we have a password created for validating to the master. Note
# this is different from the one from prompt-instance-password, which is
# used to ssh into the VMs. The username/password here is used to login to
# kubernetes cluster.
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


# Create a temp dir that'll be deleted at the end of this bash session.
#
# Vars set:
#   KUBE_TEMP
function ensure-temp-dir {
  if [[ -z ${KUBE_TEMP-} ]]; then
    KUBE_TEMP=$(mktemp -d -t kubernetes.XXXXXX)
    trap 'rm -rf "${KUBE_TEMP}"' EXIT
  fi
}


# Evaluate a json string and return required fields. Example:
# $ echo '{"action":"RunInstances", "ret_code":0}' | json_val '["action"]'
# $ RunInstance
#
# Input:
#   $1 A valid json string.
function json_val {
  python -c 'import json,sys;obj=json.load(sys.stdin);print obj'$1''
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

  # Create a 'raw' master instance from anchnet, i.e. un-provisioned.
  local master_info=$(${ANCHNET_CMD} runinstance master -p="${KUBE_INSTANCE_PASSWORD}" -i="${INSTANCE_IMAGE}")
  MASTER_INSTANCE_ID=$(echo ${master_info} | json_val '["instances"][0]')
  MASTER_EIP_ID=$(echo ${master_info} | json_val '["eips"][0]')

  # Check instance status and its external IP address.
  check-instance-status "${MASTER_INSTANCE_ID}"
  get-ip-address-from-eipid "${MASTER_EIP_ID}"
  MASTER_EIP=${EIP_ADDRESS}

  # Enable ssh without password.
  setup-instance-ssh "${MASTER_EIP}"

  echo "Created master with instance ID ${MASTER_INSTANCE_ID}, eip ID ${MASTER_EIP_ID}, master eip: ${MASTER_EIP}"
}


# Create node instances from anchnet.
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

    # Create a 'raw' node instance from anchnet, i.e. un-provisioned.
    local node_info=$(${ANCHNET_CMD} runinstance node-${i} -p="${KUBE_INSTANCE_PASSWORD}" -i="${INSTANCE_IMAGE}")
    local node_instance_id=$(echo ${node_info} | json_val '["instances"][0]')
    local node_eip_id=$(echo ${node_info} | json_val '["eips"][0]')

    # Check instance status and its external IP address.
    check-instance-status "${node_instance_id}"
    get-ip-address-from-eipid "${node_eip_id}"
    local node_eip=${EIP_ADDRESS}

    # Enable ssh without password.
    setup-instance-ssh "${node_eip}"

    echo "Created node-${i} with instance ID ${node_instance_id}, eip ID ${node_eip_id}. Node EIP: ${node_eip}"

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
#   $1 Instance ID, e.g. i-TRMTHPWG
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
#   $1 Eip ID, e.g. eip-TRMTHPWG
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
      EIP_ADDRESS=${eip}
      echo "Get Eip address ${EIP_ADDRESS}"
      break
    fi
    attempt=$(($attempt+1))
    sleep 10
  done
}


# SSH to the machine and put the host's pub key to master's authorized_key,
# so future ssh commands do not require password to login. Note however,
# if ubuntu is used, then we still need to use 'expect' to enter password
# because root login is disabled by default in ubuntu.
#
# Input:
#   $1 Instance external IP address
#
# Assumed vars:
#   KUBE_INSTANCE_PASSWORD
function setup-instance-ssh {
  # TODO: Refine expect script to take care of timeout, lost connection, etc. Now
  # we use a simple sleep to give some grace period for sshd to up.
  sleep 20
  # TODO: Use ubuntu image for now. If we use different image, user name can be 'root'.
  # Use a large timeout to tolerate ssh connection delay; otherwise, expect script will mess up.
  expect <<EOF
set timeout 360
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
# done, all instances can be reached from preconfigured private IP addresses.
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
  ${ANCHNET_CMD} joinvxnet ${VXNET_ID} ${ALL_INSTANCE_IDS} > /dev/null
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
# 1. Copies master component configurations to working directory (~/kube).
# 2. Create a master-start.sh file which applies the configs, setup network, and
#   starts k8s master.
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
    echo "mkdir -p ~/kube/default ~/kube/network ~/kube/security"
    grep -v "^#" "${KUBE_ROOT}/cluster/anchnet/config-components.sh"
    grep -v "^#" "${KUBE_ROOT}/cluster/anchnet/config-default.sh"
    echo ""
    # The following create-*-opts functions create component options (flags).
    # The flag options are stored under ~/kube/default.
    echo "create-etcd-opts kubernetes-master \"${MASTER_INTERNAL_IP}\" \"${ETCD_INITIAL_CLUSTER}\""
    echo "create-kube-apiserver-opts \"${SERVICE_CLUSTER_IP_RANGE}\""
    echo "create-kube-controller-manager-opts"
    echo "create-kube-scheduler-opts"
    echo "create-flanneld-opts ${PRIVATE_INTERFACE}"
    # Function 'create-private-interface-opts' creates network options used to
    # configure private sdn network interface.
    echo "create-private-interface-opts ${PRIVATE_INTERFACE} ${MASTER_INTERNAL_IP} ${INTERNAL_IP_MASK}"
    # The following two lines organize file structure a little bit.
    echo "mv ~/kube/known-tokens.csv ~/kube/basic-auth.csv ~/kube/security"
    echo "mv ~/kube/ca.crt ~/kube/master.crt ~/kube/master.key ~/kube/security"
    # Create the system directories used to hold the final data.
    echo "sudo mkdir -p /opt/bin"
    echo "sudo mkdir -p /etc/kubernetes"
    # Copy binaries and configurations to system directories.
    echo "sudo cp ~/kube/master/* /opt/bin"
    echo "sudo cp ~/kube/default/* /etc/default"
    echo "sudo cp ~/kube/init_conf/* /etc/init/"
    echo "sudo cp ~/kube/init_scripts/* /etc/init.d/"
    echo "sudo cp ~/kube/network/interfaces /etc/network/interfaces"
    echo "sudo cp ~/kube/security/known-tokens.csv ~/kube/security/basic-auth.csv /etc/kubernetes"
    echo "sudo cp ~/kube/security/ca.crt ~/kube/security/master.crt ~/kube/security/master.key /etc/kubernetes"
    # Restart network manager to make private sdn in effect.
    echo "sudo sed -i 's/^managed=false/managed=true/' /etc/NetworkManager/NetworkManager.conf"
    echo "sudo service network-manager restart"
    # This is tricky. k8s uses /proc/net/route to find public interface; if we do
    # not sleep here, the network-manager hasn't finished bootstrap and the routing
    # table in /proc won't be established. So k8s (e.g. api-server) will bail out
    # and complains no interface to bind.
    echo "sleep 10"
    # Finally, start kubernetes cluster. Upstart will make sure all components start
    # upon etcd start.
    echo "sudo service etcd start"
  ) > "${KUBE_TEMP}/master-start.sh"
  chmod a+x ${KUBE_TEMP}/master-start.sh

  # Copy master component configurations and startup script to master instance under
  # ~/kube. The base image we use have the binaries in place.
  scp -r -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
      ${KUBE_ROOT}/cluster/anchnet/master/* \
      ${KUBE_TEMP}/master-start.sh \
      ${KUBE_TEMP}/known-tokens.csv \
      ${KUBE_TEMP}/basic-auth.csv \
      ${KUBE_TEMP}/easy-rsa-master/easyrsa3/pki/ca.crt \
      ${KUBE_TEMP}/easy-rsa-master/easyrsa3/pki/issued/master.crt \
      ${KUBE_TEMP}/easy-rsa-master/easyrsa3/pki/private/master.key \
      "ubuntu@${MASTER_EIP}":~/kube

  # Call master-start.sh to start master.
  expect <<EOF
set timeout 360
spawn ssh -t -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
  ubuntu@${MASTER_EIP} "sudo ~/kube/master-start.sh"
expect "*assword for*"
send -- "${KUBE_INSTANCE_PASSWORD}\r"
expect eof
EOF
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
    # Create node startup script. Note we assume the base image has necessary tools
    # installed, e.g. docker, bridge-util, etc. The flow is similar to master startup
    # script.
    (
      echo "#!/bin/bash"
      echo "mkdir -p ~/kube/default ~/kube/network ~/kube/security"
      grep -v "^#" "${KUBE_ROOT}/cluster/anchnet/config-components.sh"
      grep -v "^#" "${KUBE_ROOT}/cluster/anchnet/config-default.sh"
      grep -v "^#" "${KUBE_ROOT}/cluster/anchnet/reconf-docker.sh"
      echo ""
      # Create component options.
      echo "create-etcd-opts kubernetes-node${i} \"${node_internal_ip}\" \"${ETCD_INITIAL_CLUSTER}\""
      echo "create-kubelet-opts ${node_internal_ip} \"${MASTER_INTERNAL_IP}\" \"${DNS_SERVER_IP}\" \"${DNS_DOMAIN}\" \"${POD_INFRA_CONTAINER}\""
      echo "create-kube-proxy-opts \"${MASTER_INTERNAL_IP}\""
      echo "create-flanneld-opts ${PRIVATE_INTERFACE}"
      # Create network options.
      echo "create-private-interface-opts ${PRIVATE_INTERFACE} ${node_internal_ip} ${INTERNAL_IP_MASK}"
      # Organize files a little bit.
      echo "mv ~/kube/kubelet-kubeconfig ~/kube/kube-proxy-kubeconfig ~/kube/security"
      # Create the system directories used to hold the final data.
      echo "sudo mkdir -p /opt/bin"
      echo "sudo mkdir -p /etc/kubernetes"
      # Copy binaries and configurations to system directories.
      echo "sudo cp ~/kube/node/* /opt/bin"
      echo "sudo cp ~/kube/default/* /etc/default"
      echo "sudo cp ~/kube/init_conf/* /etc/init/"
      echo "sudo cp ~/kube/init_scripts/* /etc/init.d/"
      echo "sudo cp ~/kube/network/interfaces /etc/network/interfaces"
      echo "sudo cp ~/kube/security/kubelet-kubeconfig ~/kube/security/kube-proxy-kubeconfig /etc/kubernetes"
      # Restart network manager to make private sdn in effect.
      echo "sudo sed -i 's/^managed=false/managed=true/' /etc/NetworkManager/NetworkManager.conf"
      echo "sudo service network-manager restart"
      # Same reason as to the sleep in master; but here, the affected k8s component
      # is kube-proxy.
      echo "sleep 10"
      # Finally, start kubernetes cluster.
      echo "sudo service etcd start"
      # Reconfigure docker network to use flannel overlay.
      echo "reconfig-docker-net"
    ) > "${KUBE_TEMP}/node${i}-start.sh"
    chmod a+x ${KUBE_TEMP}/node${i}-start.sh

    # Copy node component configurations and startup script to node instance. The
    # base image we use have the binaries in place.
    scp -r -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
        ${KUBE_ROOT}/cluster/anchnet/node/* \
        ${KUBE_TEMP}/node${i}-start.sh \
        ${KUBE_TEMP}/kubelet-kubeconfig \
        ${KUBE_TEMP}/kube-proxy-kubeconfig \
        "ubuntu@${node_eip}":~/kube

    # Call node${i}-start.sh to start node.
    expect <<EOF
set timeout 360
spawn ssh -t -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
  ubuntu@${node_eip} "sudo ./kube/node${i}-start.sh"
expect "*assword for*"
send -- "${KUBE_INSTANCE_PASSWORD}\r"
expect eof
EOF
    i=$(($i+1))
  done
}


# Create certificate pairs and credentials for the cluster.
# Note: Some of the code in this function is inspired from gce/util.sh,
# make-ca-cert.sh.
#
# These are used for static cert distribution (e.g. static clustering) at
# cluster creation time. This will be obsoleted once we implement dynamic
# clustering.
#
# The following certificate pairs are created:
#
#  - ca (the cluster's certificate authority)
#  - server
#  - kubelet
#  - kubectl
#
# Assumed vars
#   KUBE_TEMP
#   MASTER_EIP
#   MASTER_NAME
#   DNS_DOMAIN
#   SERVICE_CLUSTER_IP_RANGE
#
# Vars set:
#   KUBELET_TOKEN
#   KUBE_PROXY_TOKEN
#   KUBE_BEARER_TOKEN
#   CERT_DIR
#   CA_CERT - Path to ca cert
#   KUBE_CERT - Path to kubectl client cert
#   KUBE_KEY - Path to kubectl client key
#   CA_CERT_BASE64
#   MASTER_CERT_BASE64
#   MASTER_KEY_BASE64
#   KUBELET_CERT_BASE64
#   KUBELET_KEY_BASE64
#   KUBECTL_CERT_BASE64
#   KUBECTL_KEY_BASE64
#
# Files created:
#   ${KUBE_TEMP}/kubelet-kubeconfig
#   ${KUBE_TEMP}/kube-proxy-kubeconfig
#   ${KUBE_TEMP}/known-tokens.csv
#   ${KUBE_TEMP}/easy-rsa-master/easyrsa3/pki/ca.crt
#   ${KUBE_TEMP}/easy-rsa-master/easyrsa3/pki/issued/master.crt
#   ${KUBE_TEMP}/easy-rsa-master/easyrsa3/pki/private/master.key
#   ${KUBE_TEMP}/easy-rsa-master/easyrsa3/pki/issued/kubelet.crt
#   ${KUBE_TEMP}/easy-rsa-master/easyrsa3/pki/private/kubelet.key
#   ${KUBE_TEMP}/easy-rsa-master/easyrsa3/pki/issued/kubectl.crt
#   ${KUBE_TEMP}/easy-rsa-master/easyrsa3/pki/private/kubectl.key
function create-certs-and-credentials {
  # TODO: Figure out this name.
  MASTER_NAME="master"

  # 'octects' will be an arrary of segregated IP, e.g. 192.168.3.0/24 => 192 168 3 0
  # 'service_ip' is the first IP address in SERVICE_CLUSTER_IP_RANGE; it is the service
  #  created to represent kubernetes api itself, i.e. kubectl get service:
  #    NAME         LABELS                                    SELECTOR   IP(S)         PORT(S)
  #    kubernetes   component=apiserver,provider=kubernetes   <none>     192.168.3.1   443/TCP
  # 'sans' are all the possible names that the ca certifcate certifies.
  local octects=($(echo "$SERVICE_CLUSTER_IP_RANGE" | sed -e 's|/.*||' -e 's/\./ /g'))
  ((octects[3]+=1))
  local service_ip=$(echo "${octects[*]}" | sed 's/ /./g')
  local sans="IP:${MASTER_EIP},IP:${MASTER_INTERNAL_IP},IP:${service_ip}"
  sans="${sans},DNS:kubernetes,DNS:kubernetes.default,DNS:kubernetes.default.svc"
  sans="${sans},DNS:kubernetes.default.svc.${DNS_DOMAIN},DNS:${MASTER_NAME}"

  # Create cluster certificates.
  (
    cd "${KUBE_TEMP}"
    curl -L -O https://storage.googleapis.com/kubernetes-release/easy-rsa/easy-rsa.tar.gz > /dev/null 2>&1
    tar xzf easy-rsa.tar.gz > /dev/null 2>&1
    cd easy-rsa-master/easyrsa3
    ./easyrsa init-pki > /dev/null 2>&1
    ./easyrsa --batch "--req-cn=${MASTER_EIP}@$(date +%s)" build-ca nopass > /dev/null 2>&1
    ./easyrsa --subject-alt-name="${sans}" build-server-full master nopass > /dev/null 2>&1
    ./easyrsa build-client-full kubelet nopass > /dev/null 2>&1
    ./easyrsa build-client-full kubectl nopass > /dev/null 2>&1
  ) || {
    # TODO: Better error handling.
    echo "=== Failed to generate certificates: Aborting ==="
    exit 2
  }
  CERT_DIR="${KUBE_TEMP}/easy-rsa-master/easyrsa3"
  # Path to certificates, used to create kubeconfig for kubectl.
  CA_CERT="${CERT_DIR}/pki/ca.crt"
  KUBE_CERT="${CERT_DIR}/pki/issued/kubectl.crt"
  KUBE_KEY="${CERT_DIR}/pki/private/kubectl.key"
  # By default, linux wraps base64 output every 76 cols, so we use 'tr -d' to remove whitespaces.
  # Note 'base64 -w0' doesn't work on Mac OS X, which has different flags.
  CA_CERT_BASE64=$(cat "${CERT_DIR}/pki/ca.crt" | base64 | tr -d '\r\n')
  MASTER_CERT_BASE64=$(cat "${CERT_DIR}/pki/issued/master.crt" | base64 | tr -d '\r\n')
  MASTER_KEY_BASE64=$(cat "${CERT_DIR}/pki/private/master.key" | base64 | tr -d '\r\n')
  KUBELET_CERT_BASE64=$(cat "${CERT_DIR}/pki/issued/kubelet.crt" | base64 | tr -d '\r\n')
  KUBELET_KEY_BASE64=$(cat "${CERT_DIR}/pki/private/kubelet.key" | base64 | tr -d '\r\n')
  KUBECTL_CERT_BASE64=$(cat "${CERT_DIR}/pki/issued/kubectl.crt" | base64 | tr -d '\r\n')
  KUBECTL_KEY_BASE64=$(cat "${CERT_DIR}/pki/private/kubectl.key" | base64 | tr -d '\r\n')

  # Generate bearer tokens for this cluster. This may disappear, upstream issue:
  # https://github.com/GoogleCloudPlatform/kubernetes/issues/3168
  KUBELET_TOKEN=$(dd if=/dev/urandom bs=128 count=1 2>/dev/null | base64 | tr -d "=+/" | dd bs=32 count=1 2>/dev/null)
  KUBE_PROXY_TOKEN=$(dd if=/dev/urandom bs=128 count=1 2>/dev/null | base64 | tr -d "=+/" | dd bs=32 count=1 2>/dev/null)
  KUBE_BEARER_TOKEN=$(dd if=/dev/urandom bs=128 count=1 2>/dev/null | base64 | tr -d "=+/" | dd bs=32 count=1 2>/dev/null)

  # Create a username/password for accessing cluster.
  get-password

  # Create kubeconfig used by kubelet and kube-proxy to connect to apiserver.
  (
    umask 077;
    cat > "${KUBE_TEMP}/kubelet-kubeconfig" <<EOF
apiVersion: v1
kind: Config
users:
- name: kubelet
  user:
    token: ${KUBELET_TOKEN}
clusters:
- name: local
  cluster:
    certificate-authority-data: ${CA_CERT_BASE64}
contexts:
- context:
    cluster: local
    user: kubelet
  name: service-account-context
current-context: service-account-context
EOF
  )

  (
    umask 077;
    cat > "${KUBE_TEMP}/kube-proxy-kubeconfig" <<EOF
apiVersion: v1
kind: Config
users:
- name: kube-proxy
  user:
    token: ${KUBE_PROXY_TOKEN}
clusters:
- name: local
  cluster:
    certificate-authority-data: ${CA_CERT_BASE64}
contexts:
- context:
    cluster: local
    user: kube-proxy
  name: service-account-context
current-context: service-account-context
EOF
  )

  # Create known-tokens.csv used by apiserver to authenticate clients using tokens.
  (
    umask 077;
    echo "${KUBE_BEARER_TOKEN},admin,admin" > "${KUBE_TEMP}/known-tokens.csv"
    echo "${KUBELET_TOKEN},kubelet,kubelet" >> "${KUBE_TEMP}/known-tokens.csv"
    echo "${KUBE_PROXY_TOKEN},kube_proxy,kube_proxy" >> "${KUBE_TEMP}/known-tokens.csv"
  )

  # Create basic-auth.csv used by apiserver to authenticate clients using HTTP basic auth.
  (
    umask 077
    echo "${KUBE_PASSWORD},${KUBE_USER},admin" > "${KUBE_TEMP}/basic-auth.csv"
  )
}
