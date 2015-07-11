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


# TODO: Create a clean up script to stop all services, delete old configs, etc.

# When running dev, no machine will be created. Developer is responsible to
# specify the instance IDs, eip IDs, etc.
DEV_MODE=${DEV_MODE:-false}

# The base image used to create master and node instance. This image is created
# from scripts like 'image-from-devserver.sh', which install caicloud-k8s release
# binaries, docker, etc.
# This approach avoids downloading/installing when bootstrapping a cluster, which
# saves a lot of time. The image must be created from ubuntu, and has:
#   ~/kube/master - Directory containing all master binaries
#   ~/kube/node - Directory containing all node binaries
#   Installed docker
#   Installed bridge-utils
INSTANCE_IMAGE="img-OBKRMWB4"
INSTANCE_USER="ubuntu"

# Helper constants.
ANCHNET_CMD="anchnet"
DEFAULT_USER_CONFIG_FILE="${KUBE_ROOT}/cluster/anchnet/default-user-config.sh"
SYSTEM_NAMESPACE=kube-system

# Step1 of cluster bootstrapping: verify cluster prerequisites.
function verify-prereqs {
  if [[ "$(which ${ANCHNET_CMD})" == "" ]]; then
    echo "Can't find anchnet cli binary in PATH, please fix and retry."
    echo "See https://github.com/caicloud/anchnet-go/tree/master/anchnet"
    exit 1
  fi
  if [[ "$(which expect)" == "" ]]; then
    echo "Can't find expect binary in PATH, please fix and retry."
    echo "For ubuntu/debian, if you have root access, run: sudo apt-get install expect."
    exit 1
  fi
  if [[ "$(which kubectl)" == "" ]]; then
    echo "Can't find kubectl binary in PATH, please fix and retry."
    exit 1
  fi
  if [[ ! -f ~/.anchnet/config  ]]; then
    echo "Can't find anchnet config file in ~/.anchnet, please fix and retry."
    echo "File ~/.anchnet/config contains credentials used to access anchnet API."
    exit 1
  fi
}


# Step2 of cluster bootstrapping: create all machines and provision them.
function kube-up {
  KUBE_ROOT="$(dirname "${BASH_SOURCE}")/../.."

  # Create KUBE_INSTANCE_PASSWORD, which will be used to login into anchnet instances.
  if false; then
    # Disable to save some typing.
    prompt-instance-password
  fi
  KUBE_INSTANCE_PASSWORD="caicloud2015ABC"

  # Make sure we have a staging area.
  ensure-temp-dir

  # Make sure we have a public/private key pair used to provision the machine.
  ensure-pub-key

  # Get all cluster configuration parameters from config-default and user-config;
  # also create useful vars based on the information:
  #   MASTER_NAME, NODE_NAME_PREFIX
  # Note that master_name and node_name are name of the instances in anchnet, which
  # is helpful to group instances; however, anchnet API works well with instance id,
  # so we provide instance id to kubernetes as nodename and hostname, which makes it
  # easy to query anchnet in kubernetes.
  USER_CONFIG_FILE=${USER_CONFIG_FILE:-${DEFAULT_USER_CONFIG_FILE}}
  echo "Reading user configuration from ${USER_CONFIG_FILE}"
  source "${KUBE_ROOT}/cluster/anchnet/config-default.sh"
  source "${USER_CONFIG_FILE}"
  MASTER_NAME="${CLUSTER_ID}-master"
  NODE_NAME_PREFIX="${CLUSTER_ID}-node"

  # For dev, set to existing machine.
  if [[ "${DEV_MODE}" = true ]]; then
    MASTER_INSTANCE_ID="i-FF830WKU"
    MASTER_EIP_ID="eip-1ITUTNX9"
    MASTER_EIP="43.254.55.207"
    NODE_INSTANCE_IDS="i-W7X4DRTB,i-EBW0J52Y"
    NODE_EIP_IDS="eip-2EUFNTQM,eip-8KHBY6I7"
    NODE_EIPS="43.254.55.206,43.254.55.202"
    PRIVATE_SDN_INTERFACE="eth1"
  else
    # Create master/node instances from anchnet without provision. The following
    # two methods will create a set of vars to be used later:
    #   MASTER_INSTANCE_ID,  MASTER_EIP_ID,  MASTER_EIP
    #   NODE_INSTANCE_IDS,   NODE_EIP_IDS,   NODE_EIPS
    # TODO: Firewall setup, need a method create-firewall.
    create-master-instance
    create-node-instances
    # Create a private SDN; then add master, nodes to it. The IP address of the
    # machines in this network are not set yet, but will be set during provision
    # based on two variables: MASTER_INTERNAL_IP and NODE_INTERNAL_IPS. This method
    # will create one var:
    #   PRIVATE_SDN_INTERFACE - the interface created on each machine for the sdn network.
    create-sdn-network
  fi

  # Create certificates and credentials to secure cluster communication.
  create-certs-and-credentials
  # The following methods generate variables used to provision master and nodes:
  #   NODE_INTERNAL_IPS - comma separated string of node internal ips
  #   ETCD_INITIAL_CLUSTER - flag etcd_init_cluster passsed to etcd instance
  create-node-internal-ips
  create-etcd-initial-cluster

  # TODO: Add retry logic to install instances and provision instances.

  # Now start installing master/nodes all together.
  install-instances

  # Start master/nodes all together.
  provision-instances

  # common.sh defines create-kubeconfig, which is used to create client kubeconfig for
  # kubectl. To properly create kubeconfig, make sure to supply it with assumed vars.
  # TODO: Fix hardcoded CONTEXT
  source "${KUBE_ROOT}/cluster/common.sh"
  KUBE_MASTER_IP="${MASTER_EIP}:${MASTER_SECURE_PORT}"
  CONTEXT="anchnet_kubernetes"
  create-kubeconfig
}


# Step3 of cluster bootstrapping: deploy addons.
#
# TODO: This is not a standard step: we changed kube-up.sh to call this method.
# Deploying addons can't be done in kube-up because we must make sure our cluster
# is validated. In some cloudproviders, deploying addons is done at kube master,
# i.e. running as a backgroud service to repeatly check addon status.
function deploy-addons {
  # At this point, addon secrets have been created (in create-certs-and-credentials).
  # Note we have to create the secrets beforehand, so that when provisioning master,
  # it knows all the tokens (including addons). All other addons related setup will
  # need to be performed here.

  # These two files are copied from cluster/addons/dns, with gcr.io changed to dockerhub.
  local -r skydns_rc_file="${KUBE_ROOT}/cluster/anchnet/addons/skydns-rc.yaml.in"
  local -r skydns_svc_file="${KUBE_ROOT}/cluster/anchnet/addons/skydns-svc.yaml.in"

  # Replace placeholder with our configuration.
  sed -e "s/{{ pillar\['dns_replicas'\] }}/${DNS_REPLICAS}/g;s/{{ pillar\['dns_domain'\] }}/${DNS_DOMAIN}/g" ${skydns_rc_file} > ${KUBE_TEMP}/skydns-rc.yaml
  sed -e "s/{{ pillar\['dns_server'\] }}/${DNS_SERVER_IP}/g" ${skydns_svc_file} > ${KUBE_TEMP}/skydns-svc.yaml

  # Copy addon configurationss and startup script to master instance under ~/kube.
  scp -r -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
      ${KUBE_ROOT}/cluster/anchnet/addons/addons-start.sh \
      ${KUBE_ROOT}/cluster/anchnet/addons/namespace.yaml \
      ${KUBE_TEMP}/system:dns-secret \
      ${KUBE_TEMP}/skydns-rc.yaml \
      ${KUBE_TEMP}/skydns-svc.yaml \
      "${INSTANCE_USER}@${MASTER_EIP}":~/kube

  # Calling 'addons-start.sh' to start addons.
  expect <<EOF
set timeout -1
spawn ssh -t -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
  ${INSTANCE_USER}@${MASTER_EIP} "sudo ./kube/addons-start.sh"
expect {
  "*?assword*" {
    send -- "${KUBE_INSTANCE_PASSWORD}\r"
    exp_continue
  }
  eof {}
}
EOF
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
    echo "+++++ Creating public key..."
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
#   $1 A valid string for indexing json string.
#   stdin: A json string
#
# Output:
#   stdout: value at given index (empty if error occurs).
#   stderr: any parsing error
function json_val {
  python -c '
import json,sys
try:
  obj=json.load(sys.stdin)
  print obj'$1'
except:
  sys.stderr.write("Unable to parse json string, please retry\n")
'
}


# Create a single master instance from anchnet.
#
# TODO: Investigate HA master setup.
#
# Assumed vars:
#   KUBE_ROOT
#   KUBE_TEMP
#   KUBE_INSTANCE_PASSWORD
#   MASTER_NAME
#   MASTER_CPU_CORES
#   MASTER_MEM_SIZE
#
# Vars set:
#   MASTER_INSTANCE_ID
#   MASTER_EIP_ID
#   MASTER_EIP
function create-master-instance {
  echo "+++++ Creating kubernetes master from anchnet, master name: ${MASTER_NAME}"

  # Create a 'raw' master instance from anchnet, i.e. un-provisioned.
  local master_info=$(
    ${ANCHNET_CMD} runinstance "${MASTER_NAME}" -p="${KUBE_INSTANCE_PASSWORD}" \
                   -i="${INSTANCE_IMAGE}" -m="${MASTER_MEM}" -c="${MASTER_CPU_CORES}")
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
# TODO: Create nodes at once (In anchnet API, it's possible to create N instances at once).
#
# Assumed vars:
#   NUM_MINIONS
#   NODE_MEM
#   NODE_CPU_CORES
#   NODE_NAME_PREFIX
#
# Vars set:
#   NODE_INSTANCE_IDS - comma separated string of instance IDs
#   NODE_EIP_IDS - comma separated string of instance external IP IDs
#   NODE_EIPS - comma separated string of instance external IPs
function create-node-instances {
  for (( i = 0; i < ${NUM_MINIONS}; i++ )); do
    echo "+++++ Creating kubernetes ${i}th node from anchnet, node name: ${NODE_NAME_PREFIX}-${i}"

    # Create a 'raw' node instance from anchnet, i.e. un-provisioned.
    local node_info=$(
      ${ANCHNET_CMD} runinstance "${NODE_NAME_PREFIX}-${i}" -p="${KUBE_INSTANCE_PASSWORD}" \
                     -i="${INSTANCE_IMAGE}" -m="${NODE_MEM}" -c="${NODE_CPU_CORES}")
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
      if (( attempt > 20 )); then
        echo
        echo -e "${color_red}Instance $1 failed to start (sorry!)${color_norm}" >&2
        exit 1
      fi
    else
      echo "Instance $1 becomes running status"
      break
    fi
    attempt=$(($attempt+1))
    sleep $(($attempt*2))
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
      if (( attempt > 20 )); then
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
    sleep $(($attempt*2))
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
  attempt=0
  while true; do
    echo "Attempt $(($attempt+1)) to setup instance ssh for $1"
    local ok=1
    expect <<EOF || ok=0
set timeout $((($attempt+1)*3))
spawn scp -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
  $HOME/.ssh/id_rsa.pub ${INSTANCE_USER}@$1:~/host_rsa.pub
expect {
  "*?assword*" {
    send -- "${KUBE_INSTANCE_PASSWORD}\r"
    exp_continue
  }
  "lost connection" { exit 1 }
  timeout { exit 1 }
  eof {}
}
spawn ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
  ${INSTANCE_USER}@$1 "umask 077 && mkdir -p ~/.ssh && cat ~/host_rsa.pub >> ~/.ssh/authorized_keys && rm -rf ~/host_rsa.pub"
expect {
  "*?assword*" {
    send -- "${KUBE_INSTANCE_PASSWORD}\r"
    exp_continue
  }
  "lost connection" { exit 1 }
  timeout { exit 1 }
  eof {}
}
EOF
    if [[ "${ok}" == "0" ]]; then
      # We give more attempts for setting up ssh to allow slow startup.
      if (( attempt > 40 )); then
        echo
        echo -e "${color_red}Unable to setup instance ssh for $1 (sorry!)${color_norm}" >&2
        exit 1
      fi
    else
      echo -e " ${color_green}[ssh to instance working]${color_norm}"
      break
    fi
    # No need to sleep here, we increment timout in expect.
    echo -e " ${color_yellow}[ssh to instance not working yet]${color_norm}"
    attempt=$(($attempt+1))
  done
}


# Create a private SDN network in anchnet, then add master and nodes to it. Once
# done, all instances can be reached from preconfigured private IP addresses.
#
# Assumed vars:
#   VXNET_NAME
#
# Vars set:
#   PRIVATE_SDN_INTERFACE - The interface created by the SDN network
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
  PRIVATE_SDN_INTERFACE="eth1"
}


# Create a comma separated string of node internal ips based on the cluster
# config NODE_INTERNAL_IP_RANGE and NUM_MINIONS. E.g. if NODE_INTERNAL_IP_RANGE
# is 10.244.1.0/16 and NUM_MINIONS is 2, then output: "10.244.1.0,10.244.1.1".
#
# Assumed vars:
#   NODE_INTERNAL_IP_RANGE
#   NUM_MINIONS
#
# Vars set:
#   NODE_INTERNAL_IPS
function create-node-internal-ips {
  # Transform NODE_INTERNAL_IP_RANGE into different info, e.g. 10.244.1.0/16 =>
  #   cidr = 16
  #   ip_octects = 10 244 1 0
  #   mask_octects = 255 255 0 0
  cidr=($(echo "$NODE_INTERNAL_IP_RANGE" | sed -e 's|.*/||'))
  ip_octects=($(echo "$NODE_INTERNAL_IP_RANGE" | sed -e 's|/.*||' -e 's/\./ /g'))
  mask_octects=($(cdr2mask ${cidr} | sed -e 's/\./ /g'))

  # Total Number of hosts in this subnet. e.g. 10.244.1.0/16 => 65535. This number
  # excludes address all-ones address (*.255.255); for all-zeros address (*.0.0),
  # we decides how to exclude it below.
  total_count=$(((2**(32-${cidr}))-1))

  # Number of used hosts in this subnet. E.g. For 10.244.1.0/16, there are already
  # 256 addresses allocated (10.244.0.1, 10.244.0.2, etc, typically for master
  # instances), we need to exclude these IP addresses when counting the real number
  # of nodes we can use. See below comment above how we handle all-zeros address.
  used_count=0
  weight=($((2**32)) $((2**16)) $((2**8)) 1)
  for (( i = 0; i < 4; i++ )); do
    current=$(( ((255 - mask_octects[i]) & ip_octects[i]) * weight[i] ))
    used_count=$(( used_count + current ))
  done

  # If used_count is 0, then our format must be something like 10.244.0.0/16, where
  # host part is all-zeros. In this case, we add one to used_count to exclude the
  # all-zeros address. If used_count is not 0, then we already excluded all-zeros
  # address in the above calculation, e.g. for 10.244.1.0/16, we get 256 used addresses,
  # which includes all-zero address.
  local host_zeros=false
  if [[ ${used_count} == 0 ]]; then
    ((used_count+=1))
    host_zeros=true
  fi

  if (( NUM_MINIONS > (total_count - used_count) )); then
    echo "Number of nodes is larger than allowed node internal IP address"
    exit 1
  fi

  # Since we've checked the required number of hosts < total number of hosts,
  # we can just simply add 1 to previous IP.
  for (( i = 0; i < ${NUM_MINIONS}; i++ )); do
    # Avoid using all-zeros address for CIDR like 10.244.0.0/16.
    if [[ ${i} == 0 && ${host_zeros} == true ]]; then
      ((ip_octects[3]+=1))
    fi
    local ip=$(echo "${ip_octects[*]}" | sed 's/ /./g')
    if [[ -z "${NODE_INTERNAL_IPS-}" ]]; then
      NODE_INTERNAL_IPS="${ip}"
    else
      NODE_INTERNAL_IPS="${NODE_INTERNAL_IPS},${ip}"
    fi
    ((ip_octects[3]+=1))
    for (( k = 3; k > 0; k--)); do
      if [[ "${ip_octects[k]}" == "256" ]]; then
        ip_octects[k]=0
        ((ip_octects[k-1]+=1))
      fi
    done
  done
}


# Convert cidr to netmask, e.g. 16 -> 255.255.0.0
#
# Input:
#   $1 cidr
function cdr2mask {
  # Number of args to shift, 255..255, first non-255 byte, zeroes
  set -- $(( 5 - ($1 / 8) )) 255 255 255 255 $(( (255 << (8 - ($1 % 8))) & 255 )) 0 0 0
  [ $1 -gt 1 ] && shift $1 || shift
  echo ${1-0}.${2-0}.${3-0}.${4-0}
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
  for (( i = 0; i < ${NUM_MINIONS}; i++ )); do
    node_internal_ip="${node_iip_arr[i]}"
    ETCD_INITIAL_CLUSTER="$ETCD_INITIAL_CLUSTER,kubernetes-node${i}=http://${node_internal_ip}:2380"
  done
}


# The method assumes instances are running. It does the following things:
# 1. Copies master component configurations to working directory (~/kube).
# 2. Create a master-start.sh file which applies the configs, setup network, and
#   starts k8s master. The base image we use have the binaries in place.
# 3. Copies node component configurations to working directory (~/kube).
# 4. Create a node${i}-start.sh file which applies the configs, setup network, and
#   starts k8s node. The base image we use have the binaries in place.
#
# This is a long method, but it helps use do the installation concurrently.
#
# Assumed vars:
#   KUBE_ROOT
#   KUBE_TEMP
#   MASTER_EIP
#   MASTER_INTERNAL_IP
#   MASTER_INSTANCE_ID
#   NODE_EIPS
#   NODE_INTERNAL_IPS
#   ETCD_INITIAL_CLUSTER
#   SERVICE_CLUSTER_IP_RANGE
#   PRIVATE_SDN_INTERFACE
#   USER_CONFIG_FILE
#   DNS_SERVER_IP
#   DNS_DOMAIN
#   POD_INFRA_CONTAINER
function install-instances {
  local pids=""

  echo "+++++ Start installing master"
  # Create master startup script.
  (
    echo "#!/bin/bash"
    echo "mkdir -p ~/kube/default ~/kube/network ~/kube/security"
    grep -v "^#" "${KUBE_ROOT}/cluster/anchnet/config-default.sh"
    grep -v "^#" "${KUBE_ROOT}/cluster/anchnet/config-components.sh"
    grep -v "^#" "${USER_CONFIG_FILE}"
    echo ""
    echo "config-hostname ${MASTER_INSTANCE_ID}"
    # The following create-*-opts functions create component options (flags).
    # The flag options are stored under ~/kube/default.
    echo "create-etcd-opts kubernetes-master \"${MASTER_INTERNAL_IP}\" \"${ETCD_INITIAL_CLUSTER}\""
    echo "create-kube-apiserver-opts \"${SERVICE_CLUSTER_IP_RANGE}\""
    echo "create-kube-controller-manager-opts"
    echo "create-kube-scheduler-opts"
    echo "create-flanneld-opts ${PRIVATE_SDN_INTERFACE}"
    # Function 'create-private-interface-opts' creates network options used to
    # configure private sdn network interface.
    echo "create-private-interface-opts ${PRIVATE_SDN_INTERFACE} ${MASTER_INTERNAL_IP} ${INTERNAL_IP_MASK}"
    # The following lines organize file structure a little bit. To make it
    # pleasant when running the script multiple times, we ignore errors.
    echo "mv ~/kube/known-tokens.csv ~/kube/basic-auth.csv ~/kube/security 1>/dev/nul 2>&1"
    echo "mv ~/kube/ca.crt ~/kube/master.crt ~/kube/master.key ~/kube/security 1>/dev/nul 2>&1"
    echo "mv ~/kube/config ~/kube/security/anchnet-config 1>/dev/nul 2>&1"
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
    echo "sudo cp ~/kube/security/anchnet-config /etc/kubernetes"
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

  # Copy master component configs and startup scripts to master instance under ~/kube.
  scp -r -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
      ${KUBE_ROOT}/cluster/anchnet/master/* \
      ${KUBE_TEMP}/master-start.sh \
      ${KUBE_TEMP}/known-tokens.csv \
      ${KUBE_TEMP}/basic-auth.csv \
      ${KUBE_TEMP}/easy-rsa-master/easyrsa3/pki/ca.crt \
      ${KUBE_TEMP}/easy-rsa-master/easyrsa3/pki/issued/master.crt \
      ${KUBE_TEMP}/easy-rsa-master/easyrsa3/pki/private/master.key \
      ~/.anchnet/config \
      "${INSTANCE_USER}@${MASTER_EIP}":~/kube &
  pids="$pids $!"

  # Start installing nodes.
  IFS=',' read -ra node_iip_arr <<< "${NODE_INTERNAL_IPS}"
  IFS=',' read -ra node_eip_arr <<< "${NODE_EIPS}"
  IFS=',' read -ra node_instance_arr <<< "${NODE_INSTANCE_IDS}"

  for (( i = 0; i < ${NUM_MINIONS}; i++ )); do
    echo "+++++ Start installing node-${i}"
    local node_internal_ip=${node_iip_arr[${i}]}
    local node_eip=${node_eip_arr[${i}]}
    local node_instance_id=${node_instance_arr[${i}]}
    # Create node startup script. Note we assume the base image has necessary
    # tools installed, e.g. docker, bridge-util, etc. The flow is similar to
    # master startup script.
    (
      echo "#!/bin/bash"
      echo "mkdir -p ~/kube/default ~/kube/network ~/kube/security"
      grep -v "^#" "${KUBE_ROOT}/cluster/anchnet/config-default.sh"
      grep -v "^#" "${KUBE_ROOT}/cluster/anchnet/config-components.sh"
      echo ""
      echo "config-hostname ${node_instance_id}"
      # Create component options. Note in 'create-kubelet-opts', we use
      # ${node_instance_id} as hostname override for each node - see
      # 'pkg/cloudprovider/anchnet/anchnet_instances.go' for how this works.
      echo "create-etcd-opts kubernetes-node${i} ${node_internal_ip} \"${ETCD_INITIAL_CLUSTER}\""
      echo "create-kubelet-opts ${node_instance_id} ${MASTER_INTERNAL_IP} ${DNS_SERVER_IP} ${DNS_DOMAIN} ${POD_INFRA_CONTAINER}"
      echo "create-kube-proxy-opts \"${MASTER_INTERNAL_IP}\""
      echo "create-flanneld-opts ${PRIVATE_SDN_INTERFACE}"
      # Create network options.
      echo "create-private-interface-opts ${PRIVATE_SDN_INTERFACE} ${node_internal_ip} ${INTERNAL_IP_MASK}"
      # Organize files a little bit.
      echo "mv ~/kube/kubelet-kubeconfig ~/kube/kube-proxy-kubeconfig ~/kube/security 1>/dev/nul 2>&1"
      echo "mv ~/kube/config ~/kube/security/anchnet-config 1>/dev/nul 2>&1"
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
      echo "sudo cp ~/kube/security/anchnet-config /etc/kubernetes"
      # Restart network manager to make private sdn in effect.
      echo "sudo sed -i 's/^managed=false/managed=true/' /etc/NetworkManager/NetworkManager.conf"
      echo "sudo service network-manager restart"
      # Same reason as to the sleep in master; but here, the affected k8s component
      # is kube-proxy.
      echo "sleep 10"
      # Finally, start kubernetes cluster.
      echo "sudo service etcd start"
      # Configure docker network to use flannel overlay.
      echo "config-docker-net"
    ) > "${KUBE_TEMP}/node${i}-start.sh"
    chmod a+x ${KUBE_TEMP}/node${i}-start.sh

    # Copy node component configurations and startup script to node instance. The
    # base image we use have the binaries in place.
    scp -r -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
        ${KUBE_ROOT}/cluster/anchnet/node/* \
        ${KUBE_TEMP}/node${i}-start.sh \
        ${KUBE_TEMP}/kubelet-kubeconfig \
        ${KUBE_TEMP}/kube-proxy-kubeconfig \
        ~/.anchnet/config \
        "${INSTANCE_USER}@${node_eip}":~/kube &
    pids="$pids $!"
  done

  echo "+++++ Wait for all instances to be installed..."
  wait $pids
  echo "+++++ All instances have been installed...."
}


# Start master/nodes concurrently.
#
# Assumed vars:
#   KUBE_INSTANCE_PASSWORD
#   MASTER_EIP
#   NODE_EIPS
function provision-instances {
  local pids=""

  echo "+++++ Start provisioning master"
  # Call master-start.sh to start master.
  expect <<EOF &
set timeout -1
spawn ssh -t -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
  ${INSTANCE_USER}@${MASTER_EIP} "sudo ~/kube/master-start.sh"
expect {
  "*?assword*" {
    send -- "${KUBE_INSTANCE_PASSWORD}\r"
    exp_continue
  }
  eof {}
}
EOF
  pids="$pids $!"

  IFS=',' read -ra node_eip_arr <<< "${NODE_EIPS}"
  local i=0
  for node_eip in "${node_eip_arr[@]}"; do
    echo "+++++ Start provisioning node-${i}"
    # Call node${i}-start.sh to start node. Note we must run expect in background;
    # otherwise, there will be a deadlock: node0-start.sh keeps retrying for etcd
    # connection (for docker-flannel configuration) because other nodes aren't
    # ready. If we run expect in foreground, we can't start other nodes; thus node0
    # will wait until timeout.
    expect <<EOF &
set timeout -1
spawn ssh -t -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
  ${INSTANCE_USER}@${node_eip} "sudo ./kube/node${i}-start.sh"
expect {
  "*?assword*" {
    send -- "${KUBE_INSTANCE_PASSWORD}\r"
    exp_continue
  }
  eof {}
}
EOF
    pids="$pids $!"
    i=$(($i+1))
  done

  echo "Wait for all instances to be provisioned..."
  wait $pids
  echo "All instances have been provisioned..."
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
  echo "+++++ Creating certificats and credentials"

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
  sans="${sans},DNS:kubernetes.default.svc.${DNS_DOMAIN},DNS:${MASTER_NAME},DNS:master"

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
    echo "${color_red}=== Failed to generate certificates: Aborting ===${color_norm}"
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

  echo "Creating service accounts secrets..."
  # Create tokens for service accounts. 'service_accounts' refers to things that
  # provide services based on apiserver, including scheduler, controller_manager
  # and addons (Note scheduler and controller_manager are not actually used in
  # our setup, but we keep it here for tracking. The reason for having such secrets
  # for these service accounts is to run them as Pod, aka, self-hosting).
  local -r service_accounts=("system:scheduler" "system:controller_manager" "system:dns")
  for account in "${service_accounts[@]}"; do
    token=$(dd if=/dev/urandom bs=128 count=1 2>/dev/null | base64 | tr -d "=+/" | dd bs=32 count=1 2>/dev/null)
    create-kubeconfig-secret "${token}" "${account}" "https://${MASTER_EIP}:${MASTER_SECURE_PORT}" "${KUBE_TEMP}/${account}-secret"
    echo "${token},${account},${account}" >> "${KUBE_TEMP}/known-tokens.csv"
  done
}


# Create a kubeconfig file used for addons to contact apiserver. Note this is not
# used to create kubeconfig for kubelet and kube-proxy, since they have slightly
# different contents.
#
# Input:
#   $1 The base64 encoded token
#   $2 Username, e.g. system:dns
#   $3 Server to connect to, e.g. master_ip:port
#   $4 File to write the secret.
function create-kubeconfig-secret {
  local -r token=$1
  local -r username=$2
  local -r server=$3
  local -r file=$4
  local -r safe_username=$(tr -s ':_' '--' <<< "${username}")

  # Make a kubeconfig file with token.
  cat > "${KUBE_TEMP}/kubeconfig" <<EOF
apiVersion: v1
kind: Config
users:
- name: ${username}
  user:
    token: ${token}
clusters:
- name: local
  cluster:
     server: ${server}
     certificate-authority-data: ${CA_CERT_BASE64}
contexts:
- context:
    cluster: local
    user: ${username}
    namespace: ${SYSTEM_NAMESPACE}
  name: service-account-context
current-context: service-account-context
EOF

  local -r kubeconfig_base64=$(cat "${KUBE_TEMP}/kubeconfig" | base64 | tr -d '\r\n')
  cat > $4 <<EOF
apiVersion: v1
data:
  kubeconfig: ${kubeconfig_base64}
kind: Secret
metadata:
  name: token-${safe_username}
type: Opaque
EOF
}
