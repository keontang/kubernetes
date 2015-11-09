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

# In kube-up.sh, bash is set to exit on error. However, we need to retry
# on error. Therefore, we disable errexit here.
set +o errexit

# Path of kubernetes root directory.
KUBE_ROOT="$(dirname "${BASH_SOURCE}")/../.."

# Get cluster configuration parameters from config-default, and retrieve
# executor related methods from executor-service.sh. Note KUBE_DISTRO will
# be available after sourcing file config-default.sh.
source "${KUBE_ROOT}/cluster/caicloud-anchnet/config-default.sh"
source "${KUBE_ROOT}/cluster/caicloud/common.sh"
source "${KUBE_ROOT}/cluster/caicloud/executor-service.sh"
source "${KUBE_ROOT}/cluster/caicloud/${KUBE_DISTRO}/helper.sh"


# -----------------------------------------------------------------------------
# Cluster specific library utility functions.
# -----------------------------------------------------------------------------
# Step1 of cluster bootstrapping: verify cluster prerequisites.
function verify-prereqs {
  if [[ "$(which anchnet)" == "" ]]; then
    log "Can't find anchnet cli binary in PATH, please fix and retry."
    log "See https://github.com/caicloud/anchnet-go/tree/master/anchnet"
    exit 1
  fi
  if [[ "$(which curl)" == "" ]]; then
    log "Can't find curl in PATH, please fix and retry."
    log "For ubuntu/debian, if you have root access, run: sudo apt-get install curl."
    exit 1
  fi
  if [[ "$(which python)" == "" ]]; then
    log "Can't find python in PATH, please fix and retry."
    log "For ubuntu/debian, if you have root access, run: sudo apt-get install python."
    exit 1
  fi
  if [[ "$(which expect)" == "" ]]; then
    log "Can't find expect binary in PATH, please fix and retry."
    log "For ubuntu/debian, if you have root access, run: sudo apt-get install expect."
    exit 1
  fi
  if [[ "$(which kubectl)" == "" ]]; then
    caicloud-build-local
    if [[ "$(which kubectl)" == "" ]]; then
      log "Can't find kubectl binary in PATH, please fix and retry."
      exit 1
    fi
  fi
  if [[ ! -f "${ANCHNET_CONFIG_FILE}" ]]; then
    log "Can't find anchnet config file ${ANCHNET_CONFIG_FILE}, please fix and retry."
    log "Anchnet config file contains credentials used to access anchnet API."
    exit 1
  fi
  if [[ ! "${KUBE_UP_MODE}" =~ ^(image|dev|tarball)$ ]]; then
    log "${color_red}Unrecognized kube-up mode ${KUBE_UP_MODE}${color_norm}"
    exit 1
  fi
}

# Instantiate a kubernetes cluster
function kube-up {
  # Print all environment and local variables at this point.
  log "+++++ Running kube-up with variables"
  (set -o posix; set)

  # Build tarball if BUILD_TARBALL=Y; version is based on date/time.
  if [[ "${BUILD_TARBALL}" = "Y" ]]; then
    log "+++++ Building tarball"
    caicloud-build-tarball "${FINAL_VERSION}"
  fi

  # Make sure we have:
  #  1. a staging area
  #  2. ssh capability
  #  3. log directory
  ensure-temp-dir
  ensure-ssh-agent
  ensure-log-dir

  if [[ "${KUBE_UP_MODE}" = "dev" ]]; then
    # For dev, set to existing instance IDs for master and nodes. Other variables
    # will be calculated based on the IDs.
    MASTER_INSTANCE_ID="i-K64QAG7T"
    NODE_INSTANCE_IDS="i-0ZTQ6ACY,i-PR1DCP5K"
    # To mimic actual kubeup process, we create vars to match create-master-instance
    # create-node-instances, etc. We also override NUM_MINIONS.
    create-dev-variables
  else
    # Create an anchnet project if PROJECT_ID is empty.
    create-project
    # Create master/node instances from anchnet without provision. The following
    # two methods will create a set of vars to be used later:
    #   MASTER_INSTANCE_ID,  MASTER_EIP_ID,  MASTER_EIP
    #   NODE_INSTANCE_IDS,   NODE_EIP_IDS,   NODE_EIPS
    create-master-instance
    create-node-instances
    # Create a private SDN; then add master, nodes to it. The IP address of the
    # machines in this network will be set in setup-anchnet-hosts. The function
    # will create one var:
    #   PRIVATE_SDN_INTERFACE - the interface created on each machine for the sdn network.
    create-sdn-network
    # Create firewall rules for all instances. The function will create vars:
    #   MASTER_SG_ID
    #   NODE_SG_ID
    create-firewall
  fi

  # Create node internal IPs for private SDN network:
  #   NODE_IIPS
  create-node-internal-ips-variable

  # After resources are created, we create resource variables used for various
  # provisioning functions.
  #   INSTANCE_IDS, INSTANCE_EIPS, INSTANCE_IIPS
  #   INSTANCE_IDS_ARR, INSTANCE_EIPS_ARR, INSTANCE_IIPS_ARR
  #   NODE_INSTANCE_IDS_ARR, NODE_EIPS_ARR, NODE_IIPS_ARR
  create-resource-variables

  # Create certificates and credentials to secure cluster communication.
  create-certs-and-credentials \
    "${MASTER_IIP}" \
    "${MASTER_EIP}"

  # Setup host, including hostname, private SDN network, etc.
  setup-anchnet-hosts

  trap-add 'clean-up-working-dir "${MASTER_SSH_EXTERNAL}" "${NODE_SSH_EXTERNAL}"' EXIT

  # Install binaries and packages concurrently. If we are to use image mode,
  # everythingshould already be installed so there is no need to install tarball
  # and packages.
  if [[ "${KUBE_UP_MODE}" != "image" ]]; then
    local pids=""
    install-binaries-from-master \
      "${MASTER_SSH_EXTERNAL}" \
      "${NODE_SSH_EXTERNAL}" \
      "${NODE_SSH_INTERNAL}" & pids="$pids $!"
    install-packages \
      "${NODE_SSH_EXTERNAL}" & pids="$pids $!"
    wait ${pids}
  fi

  # Add project_id to cloud config.
  cp "${ANCHNET_CONFIG_FILE}" ${KUBE_TEMP}/anchnet-config
  json_add_field ${KUBE_TEMP}/anchnet-config "projectid" "${PROJECT_ID}"

  # Configure master/nodes instances.
  send-master-startup-config-files \
    "${MASTER_SSH_EXTERNAL}" \
    "${PRIVATE_SDN_INTERFACE}" \
    "anchnet" \
    "${KUBE_TEMP}/anchnet-config"

  send-node-startup-config-files \
    "${NODE_SSH_EXTERNAL}" \
    "${MASTER_IIP}" \
    "${PRIVATE_SDN_INTERFACE}" \
    "${NODE_INSTANCE_IDS}" \
    "anchnet" \
    "${KUBE_TEMP}/anchnet-config"

  # Now start kubernetes.
  start-kubernetes \
    "${MASTER_SSH_EXTERNAL}" \
    "${NODE_SSH_EXTERNAL}"

  # After everything's done, we re-apply firewall to make sure it works.
  ensure-firewall

  # common.sh defines create-kubeconfig, which is used to create client kubeconfig
  # for kubectl. To properly create kubeconfig, make sure to we supply it with
  # assumed vars (see comments from create-kubeconfig). In particular, KUBECONFIG
  # and CONTEXT.
  source "${KUBE_ROOT}/cluster/common.sh"
  # By default, kubeconfig uses https://${KUBE_MASTER_IP}. Since we use standard
  # port 443, just assign MASTER_EIP to KUBE_MASTER_EIP. If non-standard port is
  # used, then we need to set KUBE_MASTER_IP="${MASTER_EIP}:${MASTER_SECURE_PORT}"
  KUBE_MASTER_IP="${MASTER_EIP}"
  create-kubeconfig

  # Report kube-up completes. As we can't hook into validate-cluster, this is the
  # best place to report. Executor should validate cluster itself.
  kube-up-complete Y
}

# Validate a kubernetes cluster
function validate-cluster {
  # By default call the generic validate-cluster.sh script, customizable by
  # any cluster provider if this does not fit.
  "${KUBE_ROOT}/cluster/validate-cluster.sh"

  echo "... calling deploy-addons" >&2
  deploy-addons "${MASTER_SSH_EXTERNAL}"
}

# Update a kubernetes cluster with latest source.
function kube-push {
  # Find all instances and eips.
  find-instance-and-eip-resouces
  if [[ "$?" != "0" ]]; then
    log "+++++ Unable to find instances ..."
    exit 1
  fi

  # Prepare for restarting cluster. PRIVATE_SDN_INTERFACE is a hack, just like
  # in kube-up - there is no easy to find which interface serves private SDN.
  KUBE_INSTANCE_LOGDIR="/tmp/kubepush-`TZ=Asia/Shanghai date +%Y-%m-%d-%H-%M-%S`"
  PRIVATE_SDN_INTERFACE="eth1"
  ensure-temp-dir
  ensure-log-dir

  # Build client and server binaries.
  make-clean
  caicloud-build-local
  caicloud-build-server

  # Populate ssh info needed by clean-ups.
  create-node-internal-ips-variable
  create-resource-variables

  # Clean up working directory once we are done updating.
  trap-add 'clean-up-working-dir "${MASTER_SSH_EXTERNAL}" "${NODE_SSH_EXTERNAL}"' EXIT

  # Push new binaries to master.
  log "+++++ Push binaries to master ..."
  ensure-working-dir "${MASTER_SSH_EXTERNAL}"
  scp-to-instance-expect "${MASTER_SSH_EXTERNAL}" \
    "${KUBE_ROOT}/_output/dockerized/bin/linux/amd64/kube-controller-manager \
     ${KUBE_ROOT}/_output/dockerized/bin/linux/amd64/kube-apiserver \
     ${KUBE_ROOT}/_output/dockerized/bin/linux/amd64/kube-scheduler" \
    "~/kube/master"

  # Push new binaries to nodes.
  log "+++++ Push binaries to nodes ..."
  IFS=',' read -ra node_ssh_info <<< "${NODE_SSH_EXTERNAL}"
  for ssh_info in "${node_ssh_info[@]}"; do
    ensure-working-dir "${ssh_info}"
    scp-to-instance-expect "${ssh_info}" \
      "${KUBE_ROOT}/_output/dockerized/bin/linux/amd64/kubelet \
      ${KUBE_ROOT}/_output/dockerized/bin/linux/amd64/kube-proxy" \
      "~/kube/node"
  done

  # Restart cluster.
  log "+++++ Restart running cluster ..."
  stop-cluster
  install-configurations
  provision-instances
}

# Delete a kubernete cluster from anchnet, using CLUSTER_NAME.
function kube-down {
  # Find all instances prefixed with CLUSTER_NAME.
  find-instance-and-eip-resouces
  if [[ "$?" == "0" ]]; then
    anchnet-exec-and-retry "${ANCHNET_CMD} terminateinstances ${INSTANCE_IDS} --project=${PROJECT_ID}"
    anchnet-wait-job ${COMMAND_EXEC_RESPONSE} ${INSTANCE_TERMINATE_WAIT_RETRY} ${INSTANCE_TERMINATE_WAIT_INTERVAL}
    anchnet-exec-and-retry "${ANCHNET_CMD} releaseeips ${INSTANCE_EIP_IDS} --project=${PROJECT_ID}"
    anchnet-wait-job ${COMMAND_EXEC_RESPONSE} ${EIP_RELEASE_WAIT_RETRY} ${EIP_RELEASE_WAIT_INTERVAL}
  fi

  # Find all vxnets prefixed with CLUSTER_NAME.
  find-vxnet-resources
  if [[ "$?" == "0" ]]; then
    anchnet-exec-and-retry "${ANCHNET_CMD} deletevxnets ${VXNET_IDS} --project=${PROJECT_ID}"
    anchnet-wait-job ${COMMAND_EXEC_RESPONSE} ${VXNET_DELETE_WAIT_RETRY} ${VXNET_DELETE_WAIT_INTERVAL}
  fi

  # Find all security group prefixed with CLUSTER_NAME.
  find-securitygroup-resources
  if [[ "$?" == "0" ]]; then
    anchnet-exec-and-retry "${ANCHNET_CMD} deletesecuritygroups ${SECURITY_GROUP_IDS} --project=${PROJECT_ID}"
    anchnet-wait-job ${COMMAND_EXEC_RESPONSE} ${SG_DELETE_WAIT_RETRY} ${SG_DELETE_WAIT_INTERVAL}
  fi

  # TODO: Find all loadbalancers. For now, Loadbalancer is not prefixed with CLUSTER_NAME.
}

# Detect name and IP for kube master.
#
# Assumed vars:
#   MASTER_NAME
#   PROJECT_ID
#
# Vars set:
#   KUBE_MASTER
#   KUBE_MASTER_IP
function detect-master {
  local attempt=0
  while true; do
    log "Attempt $(($attempt+1)) to detect kube master"
    log "$MASTER_NAME"
    local eip=$(${ANCHNET_CMD} searchinstance ${MASTER_NAME} --project=${PROJECT_ID} | json_val '["item_set"][0]["eip"]["eip_addr"]')
    if [[ "${?}" != "0" || ! ${eip} =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
      if (( attempt > 20 )); then
        echo
        echo -e "[`TZ=Asia/Shanghai date`] ${color_red}failed to detect kube master (sorry!)${color_norm}" >&2
        exit 1
      fi
    else
      KUBE_MASTER_IP=${eip}
      break
    fi
    attempt=$(($attempt+1))
    sleep $(($attempt*2))
  done

  KUBE_MASTER=${MASTER_NAME}
  log "Using master: $KUBE_MASTER (external IP: $KUBE_MASTER_IP)"
}

# Get variables for development.
#
# Assumed vars:
#   MASTER_INSTANCE_ID
#   NODE_INSTANCE_IDS
#
# Vars set:
#   MASTER_EIP_ID
#   MASTER_EIP
#   NODE_EIP_IDS
#   NODE_EIPS
#   PRIVATE_SDN_INTERFACE
function create-dev-variables {
  anchnet-exec-and-retry "${ANCHNET_CMD} describeinstance ${MASTER_INSTANCE_ID} --project=${PROJECT_ID}"
  MASTER_EIP_ID=$(echo ${COMMAND_EXEC_RESPONSE} | json_val '["item_set"][0]["eip"]["eip_id"]')
  MASTER_EIP=$(echo ${COMMAND_EXEC_RESPONSE} | json_val '["item_set"][0]["eip"]["eip_addr"]')
  IFS=',' read -ra node_instance_ids_arr <<< "${NODE_INSTANCE_IDS}"
  for node_instance_id in ${node_instance_ids_arr[*]}; do
    anchnet-exec-and-retry "${ANCHNET_CMD} describeinstance ${node_instance_id} --project=${PROJECT_ID}"
    local node_eip_id=$(echo ${COMMAND_EXEC_RESPONSE} | json_val '["item_set"][0]["eip"]["eip_id"]')
    local node_eip=$(echo ${COMMAND_EXEC_RESPONSE} | json_val '["item_set"][0]["eip"]["eip_addr"]')
    if [[ -z "${NODE_EIPS-}" ]]; then
      NODE_EIP_IDS="${node_eip_id}"
      NODE_EIPS="${node_eip}"
    else
      NODE_EIP_IDS="${NODE_EIP_IDS},${node_eip_id}"
      NODE_EIPS="${NODE_EIPS},${node_eip}"
    fi
  done
  export NUM_MINIONS=${#node_instance_ids_arr[@]}
  PRIVATE_SDN_INTERFACE="eth1"
}

# Stop cluster stops a running cluster.
function stop-cluster {
  log "+++++ Stop master ..."
  expect <<EOF
set timeout -1
spawn ssh -t -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
  ${INSTANCE_USER}@${MASTER_EIP} "sudo service etcd stop"
expect {
  "*assword*" {
    send -- "${KUBE_INSTANCE_PASSWORD}\r"
    exp_continue
  }
  eof {}
}
EOF

  log "+++++ Stop nodes ..."
  IFS=',' read -ra node_eips_arr <<< "${NODE_EIPS}"
  for (( i = 0; i < $(($NUM_MINIONS)); i++ )); do
    local node_eip=${NODE_EIPS_ARR[${i}]}
    expect <<EOF
set timeout -1
spawn ssh -t -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
  ${INSTANCE_USER}@${node_eip} "sudo service flanneld stop"
expect {
  "*assword*" {
    send -- "${KUBE_INSTANCE_PASSWORD}\r"
    exp_continue
  }
  eof {}
}
EOF
  done
}

# Find instances and eips in anchnet via CLUSTER_NAME and PROJECT_ID. Return 1 if
# no resource is found. By convention, every instance is prefixed with CLUSTER_NAME.
#
# Assumed vars:
#   CLUSTER_NAME
#   PROJECT_ID
#
# Vars set:
#   MASTER_INSTANCE_ID
#   MASTER_EIP
#   MASTER_EIP_ID
#   NODE_INSTANCE_IDS
#   NODE_EIPS
#   NODE_EIP_IDS
#   NUM_MINIONS
#   INSTANCE_IDS
#   INSTANCE_EIPS
#   INSTANCE_EIP_IDS
#   TOTAL_COUNT
function find-instance-and-eip-resouces {
  anchnet-exec-and-retry "${ANCHNET_CMD} searchinstance ${CLUSTER_NAME} --project=${PROJECT_ID}"
  TOTAL_COUNT=$(echo ${COMMAND_EXEC_RESPONSE} | json_len '["item_set"]')
  if [[ "${TOTAL_COUNT}" = "" ]]; then
    return 1
  fi
  # Print and collect instance information.
  for i in `seq 0 $(($TOTAL_COUNT-1))`; do
    instance_name=$(echo ${COMMAND_EXEC_RESPONSE} | json_val "['item_set'][$i]['instance_name']")
    instance_id=$(echo ${COMMAND_EXEC_RESPONSE} | json_val "['item_set'][$i]['instance_id']")
    eip=$(echo ${COMMAND_EXEC_RESPONSE} | json_val "['item_set'][$i]['eip']['eip_addr']")
    eip_id=$(echo ${COMMAND_EXEC_RESPONSE} | json_val "['item_set'][$i]['eip']['eip_id']")
    log "Found instances: ${instance_name},${instance_id},${eip_id},${eip}"
    if [[ ${instance_name} == *"master"* ]]; then
      MASTER_EIP=${eip}
      MASTER_EIP_ID=${eip_id}
      MASTER_INSTANCE_ID=${instance_id}
    else
      if [[ -z "${NODE_INSTANCE_IDS-}" ]]; then
        NODE_EIPS="${eip}"
        NODE_EIP_IDS="${eip_id}"
        NODE_INSTANCE_IDS="${instance_id}"
      else
        NODE_EIPS="${NODE_EIPS},${eip}"
        NODE_EIP_IDS="${NODE_EIP_IDS},${eip_id}"
        NODE_INSTANCE_IDS="${NODE_INSTANCE_IDS},${instance_id}"
      fi
    fi
  done
  if [[ -z "${NODE_INSTANCE_IDS-}" ]]; then
    INSTANCE_IDS="${MASTER_INSTANCE_ID}"
    INSTANCE_EIPS="${MASTER_EIP}"
    INSTANCE_EIP_IDS="${MASTER_EIP_ID}"
    NODE_EIPS_ARR=""
    NODE_EIP_IDS_ARR=""
    NODE_INSTANCE_IDS_ARR=""
    export NUM_MINIONS=0
  else
    INSTANCE_IDS="${MASTER_INSTANCE_ID},${NODE_INSTANCE_IDS}"
    INSTANCE_EIPS="${MASTER_EIP},${NODE_EIPS}"
    INSTANCE_EIP_IDS="${MASTER_EIP_ID},${NODE_EIP_IDS}"
    IFS=',' read -ra NODE_EIPS_ARR <<< "${NODE_EIPS}"
    IFS=',' read -ra NODE_EIP_IDS_ARR <<< "${NODE_EIP_IDS}"
    IFS=',' read -ra NODE_INSTANCE_IDS_ARR <<< "${NODE_INSTANCE_IDS}"
    export NUM_MINIONS=${#NODE_EIPS_ARR[@]}
  fi
}

# Find vxnets in anchnet via CLUSTER_NAME and PROJECT_ID. Return 1 if no resource is found.
# By convention, every vxnet name is prefixed with CLUSTER_NAME.
#
# Assumed vars:
#   CLUSTER_NAME
#   PROJECT_ID
#
# Vars set:
#   VXNET_IDS
#   TOTAL_COUNT
function find-vxnet-resources {
  anchnet-exec-and-retry "${ANCHNET_CMD} searchvxnets ${CLUSTER_NAME} --project=${PROJECT_ID}"
  TOTAL_COUNT=$(echo ${COMMAND_EXEC_RESPONSE} | json_len '["item_set"]')
  if [[ "${TOTAL_COUNT}" = "" || "${TOTAL_COUNT}" = "1" ]]; then
    return 1
  fi
  for i in `seq 0 $(($TOTAL_COUNT-1))`; do
    vxnet_id=$(echo ${COMMAND_EXEC_RESPONSE} | json_val "['item_set'][$i]['vxnet_id']")
    if [[ "${vxnet_id}" = "vxnet-0" ]]; then
      continue
    fi
    vxnet_name=$(echo ${COMMAND_EXEC_RESPONSE} | json_val "['item_set'][$i]['vxnet_name']")
    log "Found vxnets: ${vxnet_name},${vxnet_id}"
    if [[ -z "${VXNET_IDS-}" ]]; then
      VXNET_IDS="${vxnet_id}"
    else
      VXNET_IDS="${VXNET_IDS},${vxnet_id}"
    fi
  done
}

# Find security group in anchnet via CLUSTER_NAME and PROJECT_ID. Return 1 if no resource is
# found. By convention, every security group name is prefixed with CLUSTER_NAME.
#
# Assumed vars:
#   CLUSTER_NAME
#   PROJECT_ID
#
# Vars set:
#   SECURITY_GROUP_IDS
#   TOTAL_COUNT
function find-securitygroup-resources {
  anchnet-exec-and-retry "${ANCHNET_CMD} searchsecuritygroup ${CLUSTER_NAME} --project=${PROJECT_ID}"
  TOTAL_COUNT=$(echo ${COMMAND_EXEC_RESPONSE} | json_len '["item_set"]')
  if [[ "${TOTAL_COUNT}" == "" ]]; then
    return 1
  fi
  for i in `seq 0 $(($TOTAL_COUNT-1))`; do
    security_group_name=$(echo ${COMMAND_EXEC_RESPONSE} | json_val "['item_set'][$i]['security_group_name']")
    security_group_id=$(echo ${COMMAND_EXEC_RESPONSE} | json_val "['item_set'][$i]['security_group_id']")
    log "Found security group: ${security_group_name},${security_group_id}"
    if [[ -z "${SECURITY_GROUP_IDS-}" ]]; then
      SECURITY_GROUP_IDS="${security_group_id}"
    else
      SECURITY_GROUP_IDS="${SECURITY_GROUP_IDS},${security_group_id}"
    fi
  done
}

# Create resource variables for follow-up functions. This is called when master
# and nodes have started, and their IDs and EIPs have been recorded. The function
# will make two kinds of vars: 1. concatenate master and node vars; 2. create
# array for comma separated string.
#
# Assumed vars:
#   INSTANCE_USER
#   KUBE_INSTANCE_PASSWORD
#   MASTER_INSTANCE_ID
#   MASTER_EIP
#   MASTER_IIP
#   NODE_INSTANCE_IDS
#   NODE_EIPS
#
# Vars set:
#   INSTANCE_IDS
#   INSTANCE_EIPS
#   INSTANCE_IIPS
#   INSTANCE_IDS_ARR
#   INSTANCE_EIPS_ARR
#   INSTANCE_IIPS_ARR
#   NODE_INSTANCE_IDS_ARR
#   NODE_EIPS_ARR
#   NODE_IIPS_ARR
#   NODE_IIPS
function create-resource-variables {
  INSTANCE_IDS="${MASTER_INSTANCE_ID},${NODE_INSTANCE_IDS}"
  INSTANCE_EIPS="${MASTER_EIP},${NODE_EIPS}"
  INSTANCE_IIPS="${MASTER_IIP},${NODE_IIPS}"
  IFS=',' read -ra INSTANCE_IDS_ARR <<< "${INSTANCE_IDS}"
  IFS=',' read -ra INSTANCE_EIPS_ARR <<< "${INSTANCE_EIPS}"
  IFS=',' read -ra INSTANCE_IIPS_ARR <<< "${INSTANCE_IIPS}"
  IFS=',' read -ra NODE_INSTANCE_IDS_ARR <<< "${NODE_INSTANCE_IDS}"
  IFS=',' read -ra NODE_EIPS_ARR <<< "${NODE_EIPS}"
  IFS=',' read -ra NODE_IIPS_ARR <<< "${NODE_IIPS}"
  MASTER_SSH_EXTERNAL="${INSTANCE_USER}:${KUBE_INSTANCE_PASSWORD}@${MASTER_EIP}"
  MASTER_SSH_INTERNAL="${INSTANCE_USER}:${KUBE_INSTANCE_PASSWORD}@${MASTER_IIP}"
  NODE_SSH_EXTERNAL=""
  for node_eip in "${NODE_EIPS_ARR[@]}"; do
    if [[ -z "${NODE_SSH_EXTERNAL-}" ]]; then
      NODE_SSH_EXTERNAL="${INSTANCE_USER}:${KUBE_INSTANCE_PASSWORD}@${node_eip}"
    else
      NODE_SSH_EXTERNAL="${NODE_SSH_EXTERNAL},${INSTANCE_USER}:${KUBE_INSTANCE_PASSWORD}@${node_eip}"
    fi
  done
  NODE_SSH_INTERNAL=""
  for node_iip in "${NODE_IIPS_ARR[@]}"; do
    if [[ -z "${NODE_SSH_INTERNAL-}" ]]; then
      NODE_SSH_INTERNAL="${INSTANCE_USER}:${KUBE_INSTANCE_PASSWORD}@${node_iip}"
    else
      NODE_SSH_INTERNAL="${NODE_SSH_INTERNAL},${INSTANCE_USER}:${KUBE_INSTANCE_PASSWORD}@${node_iip}"
    fi
  done
  INSTANCE_SSH_EXTERNAL="${MASTER_SSH_EXTERNAL},${NODE_SSH_EXTERNAL}"
  INSTANCE_SSH_INTERNAL="${MASTER_SSH_INTERNAL},${NODE_SSH_INTERNAL}"
}

# Create an anchnet project if PROJECT_ID is not specified, and report it back
# to executor. Note that we do not create anchnet project if neither PROJECT_ID
# nor SUB_ACCOUNT_USER is specified, this is primarily used for development.
#
# Assumed vars:
#   INITIAL_DEPOSIT
#
# Vars set:
#   PROJECT_ID
function create-project {
  if [[ ! -z "${PROJECT_ID-}" && ! -z "${SUB_ACCOUNT_USER-}" ]]; then
    # If both PROJECT_ID and SUB_ACCOUNT_USER are given, make sure the project
    # actually belongs to the user.
    anchnet-exec-and-retry "${ANCHNET_CMD} describeprojects ${PROJECT_ID}"
    PROJECT_NAME=$(echo ${COMMAND_EXEC_RESPONSE} | json_val "['item_set'][0]['project_name']")
    if [[ "${PROJECT_NAME}" != "${SUB_ACCOUNT_USER}" ]]; then
      log "+++++ ${color_red}project_id ${PROJECT_ID} doesn't belong to user ${SUB_ACCOUNT_USER}${color_norm}"
      kube-up-complete N
      exit 1
    fi
  elif [[ -z "${PROJECT_ID-}" && ! -z "${SUB_ACCOUNT_USER-}" ]]; then
    # If SUB_ACCOUNT_USER is given but PROJECT_ID is empyt, then we might need
    # to create a project in anchnet. First, we query anchnet to see if we've
    # already created project for the SUB_ACCOUNT_USER.
    anchnet-exec-and-retry "${ANCHNET_CMD} searchuserproject ${SUB_ACCOUNT_USER}"
    PROJECT_ID=$(echo ${COMMAND_EXEC_RESPONSE} | json_val "['item_set'][0]['project_id']")
    if [[ -z "${PROJECT_ID-}" ]]; then
      # If PROJECT_ID is still empty, we create anchnet project (sub account).
      log "+++++ Create new anchnet sub account for ${SUB_ACCOUNT_USER}"
      anchnet-exec-and-retry "${ANCHNET_CMD} createuserproject ${SUB_ACCOUNT_USER}"
      anchnet-wait-job ${COMMAND_EXEC_RESPONSE} ${USER_PROJECT_WAIT_RETRY} ${USER_PROJECT_WAIT_INTERVAL}
      PROJECT_ID=$(echo ${COMMAND_EXEC_RESPONSE} | json_val "['api_id']")
      # Get the userId of the sub account. Note the userId here is used internally
      # by anchnet which will be used to tranfer money.
      anchnet-exec-and-retry "${ANCHNET_CMD} describeprojects ${PROJECT_ID}"
      SUB_ACCOUNT_UID=$(echo ${COMMAND_EXEC_RESPONSE} | json_val "['item_set'][0]['userid']")
      # Transfer money from main account to sub-account. We need at least $INITIAL_DEPOSIT
      # to create resources in sub-account.
      log "+++++ Transfer balance to sub account"
      anchnet-exec-and-retry "${ANCHNET_CMD} transfer ${SUB_ACCOUNT_UID} ${INITIAL_DEPOSIT}"
      report-project-id ${PROJECT_ID}
    else
      log "+++++ Reuse existing project ID ${PROJECT_ID} for ${SUB_ACCOUNT_USER}"
      report-project-id ${PROJECT_ID}
    fi
  fi
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
  log "+++++ Create kubernetes master from anchnet, master name: ${MASTER_NAME}"

  # Create a 'raw' master instance from anchnet, i.e. un-provisioned.
  anchnet-exec-and-retry "${ANCHNET_CMD} runinstance ${MASTER_NAME} \
-p=${KUBE_INSTANCE_PASSWORD} -i=${FINAL_IMAGE} -m=${MASTER_MEM} \
-c=${MASTER_CPU_CORES} -g=${IP_GROUP} --project=${PROJECT_ID}"
  anchnet-wait-job ${COMMAND_EXEC_RESPONSE} ${MASTER_WAIT_RETRY} ${MASTER_WAIT_INTERVAL}

  # Get master information.
  local master_info=${COMMAND_EXEC_RESPONSE}
  MASTER_INSTANCE_ID=$(echo ${master_info} | json_val '["instances"][0]')
  MASTER_EIP_ID=$(echo ${master_info} | json_val '["eips"][0]')

  # Check instance status and its external IP address.
  check-instance-status "${MASTER_INSTANCE_ID}"
  get-ip-address-from-eipid "${MASTER_EIP_ID}"
  MASTER_EIP=${EIP_ADDRESS}

  # Enable ssh without password and enable sudoer for ${INSTANCE_USER}.
  setup-instance "${MASTER_EIP}" "${INSTANCE_USER}" "${KUBE_INSTANCE_PASSWORD}" "${LOGIN_USER}" "${LOGIN_PWD}"

  echo -e "[`TZ=Asia/Shanghai date`] ${color_green}[created master with instance ID ${MASTER_INSTANCE_ID}, \
eip ID ${MASTER_EIP_ID}, master eip: ${MASTER_EIP}]${color_norm}"
  report-instance-ids ${MASTER_INSTANCE_ID} M
  report-eip-ids ${MASTER_EIP_ID}
  report-ips ${MASTER_EIP} M
}

# Create node instances from anchnet.
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
  log "+++++ Create kubernetes nodes from anchnet, node name prefix: ${NODE_NAME_PREFIX} ..."

  # Create 'raw' node instances from anchnet, i.e. un-provisioned.
  anchnet-exec-and-retry "${ANCHNET_CMD} runinstance ${NODE_NAME_PREFIX} \
-p=${KUBE_INSTANCE_PASSWORD} -i=${FINAL_IMAGE} -m=${NODE_MEM} \
-c=${NODE_CPU_CORES} -g=${IP_GROUP} -a=${NUM_MINIONS} --project=${PROJECT_ID}"
  anchnet-wait-job ${COMMAND_EXEC_RESPONSE} ${NODES_WAIT_RETRY} ${NODES_WAIT_INTERVAL}

  # Node name starts from 1.
  for (( i = 1; i < $(($NUM_MINIONS+1)); i++ )); do
    # Get node information.
    local node_info=${COMMAND_EXEC_RESPONSE}
    local node_instance_id=$(echo ${node_info} | json_val "['instances'][$(($i-1))]")
    local node_eip_id=$(echo ${node_info} | json_val "['eips'][$(($i-1))]")

    # Check instance status and its external IP address.
    check-instance-status "${node_instance_id}"
    get-ip-address-from-eipid "${node_eip_id}"
    local node_eip=${EIP_ADDRESS}

    # Enable ssh without password and enable sudoer for ${INSTANCE_USER}.
    setup-instance "${node_eip}" "${INSTANCE_USER}" "${KUBE_INSTANCE_PASSWORD}" "${LOGIN_USER}" "${LOGIN_PWD}"

    echo -e "[`TZ=Asia/Shanghai date`] ${color_green}[created node-${i} with instance ID ${node_instance_id}, \
eip ID ${node_eip_id}. Node EIP: ${node_eip}]${color_norm}"

    # Set output vars. Note we use ${NODE_EIPS-} to check if NODE_EIPS is unset,
    # as top-level script has 'set -o nounset'.
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

  echo -e "[`TZ=Asia/Shanghai date`] ${color_green}[Created cluster nodes with instance IDs ${NODE_INSTANCE_IDS}, \
eip IDs ${NODE_EIP_IDS}, node eips ${NODE_EIPS}]${color_norm}"
  report-instance-ids ${NODE_INSTANCE_IDS} N
  report-eip-ids ${NODE_EIP_IDS}
  report-ips ${NODE_EIPS} N
}

# Check instance status from anchnet, break out until it's in running status.
#
# Input:
#   $1 Instance ID, e.g. i-TRMTHPWG
function check-instance-status {
  local attempt=0
  while true; do
    log "Attempt $(($attempt+1)) to check for instance running"
    local status=$(${ANCHNET_CMD} describeinstance $1 --project=${PROJECT_ID} | json_val '["item_set"][0]["status"]')
    if [[ ${status} != "running" ]]; then
      if (( attempt > 20 )); then
        echo
        echo -e "[`TZ=Asia/Shanghai date`] ${color_red}instance $1 failed to start (sorry!)${color_norm}" >&2
        kube-up-complete N
        exit 1
      fi
    else
      echo -e "[`TZ=Asia/Shanghai date`] ${color_green}[instance $1 becomes running status]${color_norm}"
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
    log "Attempt $(($attempt+1)) to get eip"
    local eip=$(${ANCHNET_CMD} describeeips $1 --project=${PROJECT_ID} | json_val '["item_set"][0]["eip_addr"]')
    # Test the return value roughly matches ipv4 format.
    if [[ ! ${eip} =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
      if (( attempt > 20 )); then
        echo
        echo -e "[`TZ=Asia/Shanghai date`] ${color_red}failed to get eip address (sorry!)${color_norm}" >&2
        kube-up-complete N
        exit 1
      fi
    else
      EIP_ADDRESS=${eip}
      echo -e "[`TZ=Asia/Shanghai date`] ${color_green}[get eip address ${EIP_ADDRESS} for $1]${color_norm}"
      break
    fi
    attempt=$(($attempt+1))
    sleep $(($attempt*2))
  done
}

# Create a private SDN network in anchnet, then add master and nodes to it.
#
# Assumed vars:
#   VXNET_NAME
#
# Vars set:
#   VXNET_ID
#   PRIVATE_SDN_INTERFACE - The interface created by the SDN network
function create-sdn-network {
  log "+++++ Create private SDN network ..."

  # Create a private SDN network.
  anchnet-exec-and-retry "${ANCHNET_CMD} createvxnets ${CLUSTER_NAME}-${VXNET_NAME} --project=${PROJECT_ID}"
  anchnet-wait-job ${COMMAND_EXEC_RESPONSE} ${VXNET_CREATE_WAIT_RETRY} ${VXNET_CREATE_WAIT_INTERVAL}

  # Get vxnet information.
  local vxnet_info=${COMMAND_EXEC_RESPONSE}
  VXNET_ID=$(echo ${vxnet_info} | json_val '["vxnets"][0]')

  # Add all instances to the vxnet.
  local all_instance_ids="${MASTER_INSTANCE_ID},${NODE_INSTANCE_IDS}"
  log "Add all instances (both master and nodes) to vxnet ${VXNET_ID} ..."
  anchnet-exec-and-retry "${ANCHNET_CMD} joinvxnet ${VXNET_ID} ${all_instance_ids} --project=${PROJECT_ID}"
  anchnet-wait-job ${COMMAND_EXEC_RESPONSE} ${VXNET_JOIN_WAIT_RETRY} ${VXNET_JOIN_WAIT_INTERVAL}

  # TODO: This is almost always true in anchnet ubuntu image. We can do better using describevxnets.
  PRIVATE_SDN_INTERFACE="eth1"
}

# Create firewall rules to allow certain traffic.
#
# Assumed vars:
#   MASTER_SECURE_PORT
#   MASTER_INSTANCE_ID
#   NODE_INSTANCE_IDS
#
# Vars set:
#   MASTER_SG_ID
#   NODE_SG_ID
function create-firewall {
  #
  # Master security group contains firewall for https (tcp/433) and ssh (tcp/22).
  #
  log "+++++ Create master security group rules ..."
  anchnet-exec-and-retry "${ANCHNET_CMD} createsecuritygroup ${CLUSTER_NAME}-${MASTER_SG_NAME} \
--rulename=master-ssh,master-https --priority=1,2 --action=accept,accept --protocol=tcp,tcp \
--direction=0,0 --value1=22,${MASTER_SECURE_PORT} --value2=22,${MASTER_SECURE_PORT} --project=${PROJECT_ID}"
  anchnet-wait-job ${COMMAND_EXEC_RESPONSE} ${SG_MASTER_WAIT_RETRY} ${SG_MASTER_WAIT_INTERVAL}

  # Get security group information.
  local master_sg_info=${COMMAND_EXEC_RESPONSE}
  MASTER_SG_ID=$(echo ${master_sg_info} | json_val '["security_group_id"]')

  # Now, apply all above changes.
  report-security-group-ids ${MASTER_SG_ID} M
  anchnet-exec-and-retry "${ANCHNET_CMD} applysecuritygroup ${MASTER_SG_ID} ${MASTER_INSTANCE_ID} --project=${PROJECT_ID}"
  anchnet-wait-job ${COMMAND_EXEC_RESPONSE}

  #
  # Node security group contains firewall for ssh (tcp/22) and nodeport range
  # (tcp/30000-32767, udp/30000-32767).
  #
  log "+++++ Create node security group rules ..."
  anchnet-exec-and-retry "${ANCHNET_CMD} createsecuritygroup ${CLUSTER_NAME}-${NODE_SG_NAME} \
--rulename=node-ssh,nodeport-range-tcp,nodeport-range-udp --priority=1,2,3 \
--action=accept,accept,accept --protocol=tcp,tcp,udp --direction=0,0,0 \
--value1=22,30000,30000 --value2=22,32767,32767 --project=${PROJECT_ID}"
  anchnet-wait-job ${COMMAND_EXEC_RESPONSE} ${SG_NODES_WAIT_RETRY} ${SG_NODES_WAIT_INTERVAL}

  # Get security group information.
  local node_sg_info=${COMMAND_EXEC_RESPONSE}
  NODE_SG_ID=$(echo ${node_sg_info} | json_val '["security_group_id"]')

  # Now, apply all above changes.
  report-security-group-ids ${NODE_SG_ID} N
  anchnet-exec-and-retry "${ANCHNET_CMD} applysecuritygroup ${NODE_SG_ID} ${NODE_INSTANCE_IDS} --project=${PROJECT_ID}"
  anchnet-wait-job ${COMMAND_EXEC_RESPONSE}
}

# Re-apply firewall to make sure firewall is properly set up.
function ensure-firewall {
  if [[ ! -z "${MASTER_SG_ID-}" && ! -z "${NODE_SG_ID-}" ]]; then
    anchnet-exec-and-retry "${ANCHNET_CMD} applysecuritygroup ${MASTER_SG_ID} ${MASTER_INSTANCE_ID} --project=${PROJECT_ID}"
    anchnet-exec-and-retry "${ANCHNET_CMD} applysecuritygroup ${NODE_SG_ID} ${NODE_INSTANCE_IDS} --project=${PROJECT_ID}"
  fi
}

# Create private interface opts, used by network manager to bring up private SDN
# network interface.
#
# Input:
#   $1 Interface name, e.g. eth1
#   $2 Static private address, e.g. 10.244.0.1
#   $3 Private address master, e.g. 255.255.0.0
#   $4 File to write network config to
function create-private-interface-opts {
  cat <<EOF > ${4}
auto lo
iface lo inet loopback
auto ${1}
iface ${1} inet static
address ${2}
netmask ${3}
EOF
}

# Create a master upgrade script used to upgrade an existing master.
#
# Input:
#   $1 File to store the script.
#
# Assumed vars:
#   ADMISSION_CONTROL
#   CLUSTER_NAME
#   FLANNEL_NET
#   PRIVATE_SDN_INTERFACE
#   SERVICE_CLUSTER_IP_RANGE
function create-master-upgrade-script {
  (
    echo "#!/bin/bash"
    grep -v "^#" "${KUBE_ROOT}/cluster/anchnet/config-default.sh"
    grep -v "^#" "${KUBE_ROOT}/cluster/anchnet/config-components.sh"
    echo ""
    echo "create-etcd-opts kubernetes-master"
    echo "create-kube-apiserver-opts ${SERVICE_CLUSTER_IP_RANGE} ${ADMISSION_CONTROL} ${CLUSTER_NAME}"
    echo "create-kube-controller-manager-opts ${CLUSTER_NAME}"
    echo "create-kube-scheduler-opts"
    echo "create-flanneld-opts ${PRIVATE_SDN_INTERFACE} 127.0.0.1"
    echo "sudo service etcd stop"
    echo "sudo cp ~/kube/master/* /opt/bin"
    echo "sudo cp ~/kube/default/* /etc/default"
    echo "sudo cp ~/kube/init_conf/* /etc/init/"
    echo "sudo cp ~/kube/init_scripts/* /etc/init.d/"
    echo "sudo service etcd start"
  ) > "$1"
  chmod a+x "$1"
}

# Create a node upgrade script used to upgrade an existing node.
#
# Input:
#   $1 File to store the script.
#   $2 Instance id of the node.
#
# Assumed vars:
#   DNS_DOMAIN
#   DNS_SERVER_IP
#   KUBELET_IP_ADDRESS
#   MASTER_IIP
#   PRIVATE_SDN_INTERFACE
#   POD_INFRA_CONTAINER
function create-node-upgrade-script {
  (
    echo "#!/bin/bash"
    grep -v "^#" "${KUBE_ROOT}/cluster/anchnet/config-default.sh"
    grep -v "^#" "${KUBE_ROOT}/cluster/anchnet/config-components.sh"
    echo ""
    echo "create-kubelet-opts ${2} ${KUBELET_IP_ADDRESS} ${MASTER_IIP} ${DNS_SERVER_IP} ${DNS_DOMAIN} ${POD_INFRA_CONTAINER}"
    echo "create-kube-proxy-opts ${MASTER_IIP}"
    echo "create-flanneld-opts ${PRIVATE_SDN_INTERFACE} ${MASTER_IIP}"
    echo "sudo service flanneld stop"
    echo "mv ~/kube/fluentd-es.yaml ~/kube/manifest/fluentd-es.yaml 1>/dev/null 2>&1"
    echo "sudo cp ~/kube/node/* /opt/bin"
    echo "sudo cp ~/kube/default/* /etc/default"
    echo "sudo cp ~/kube/init_conf/* /etc/init/"
    echo "sudo cp ~/kube/init_scripts/* /etc/init.d/"
    echo "sudo cp ~/kube/manifest/fluentd-es.yaml /etc/kubernetes/manifest"
    echo "sudo service flanneld start"
  ) > "$1"
  chmod a+x "$1"
}

# Setup anchnet hosts, including hostname, interconnection and private SDN network.
# For SDN network, this will assign internal IP address to all instances' private
# SDN interface.  Once done, all instances can be reached from preconfigured private
# IP addresses.
#
# Assumed vars:
#   KUBE_TEMP
#   INSTANCE_IIPS_ARR
#   INSTANCE_EIPS_ARR
#   INSTANCE_IDS_ARR
#   INTERNAL_IP_MASK
#   MASTER_INSTANCE_ID
#   MASTER_IIP
#   NODE_INSTANCE_IDS_ARR
#   NODE_IIPS_ARR
#   PRIVATE_SDN_INTERFACE
#   KUBE_INSTANCE_LOGDIR
function setup-anchnet-hosts {
  # Use multiple retries since seting up sdn network is essential for follow-up
  # installations, and we ses occational errors:
  # https://github.com/caicloud/caicloud-kubernetes/issues/175
  command-exec-and-retry "setup-anchnet-hosts-internal" 5
}
# Setup hosts before installing kubernetes. This is cloudprovider specific setup.
function setup-anchnet-hosts-internal {
  local pids=""

  # Setup master instance.
  (
    echo "#!/bin/bash"
    grep -v "^#" "${KUBE_ROOT}/cluster/caicloud/${KUBE_DISTRO}/helper.sh"
    echo ""
    echo "config-hostname ${MASTER_INSTANCE_ID}"
    # Make sure master is able to find nodes using node hostname.
    for (( i = 0; i < ${NUM_MINIONS}; i++ )); do
      echo "add-hosts-entry ${NODE_INSTANCE_IDS_ARR[$i]} ${NODE_IIPS_ARR[$i]}"
    done
    echo "setup-network"
  ) > "${KUBE_TEMP}/master-host-setup.sh"
  chmod a+x "${KUBE_TEMP}/master-host-setup.sh"
  create-private-interface-opts ${PRIVATE_SDN_INTERFACE} ${MASTER_IIP} ${INTERNAL_IP_MASK} "${KUBE_TEMP}/master-network-opts"

  scp-then-execute-expect "${MASTER_SSH_EXTERNAL}" "${KUBE_TEMP}/master-network-opts ${KUBE_TEMP}/master-host-setup.sh" "~" "\
mkdir -p ~/kube && \
sudo mv ~/master-host-setup.sh ~/kube && \
sudo rm -rf /etc/network/interfaces && sudo mv ~/master-network-opts /etc/network/interfaces && \
sudo ./kube/master-host-setup.sh || \
echo 'Command failed setting up remote host'" & pids="${pids} $!"

  # Setup node instances.
  IFS=',' read -ra node_ssh_info <<< "${NODE_SSH_EXTERNAL}"
  for (( i = 0; i < ${#node_ssh_info[*]}; i++ )); do
    local node_instance_id=${NODE_INSTANCE_IDS_ARR[${i}]}
    local node_iip=${NODE_IIPS_ARR[${i}]}
    (
      echo "#!/bin/bash"
      grep -v "^#" "${KUBE_ROOT}/cluster/caicloud/${KUBE_DISTRO}/helper.sh"
      echo ""
      echo "config-hostname ${node_instance_id}"
      echo "setup-network"
    ) > "${KUBE_TEMP}/node${i}-host-setup.sh"
    chmod a+x "${KUBE_TEMP}/node${i}-host-setup.sh"
    create-private-interface-opts ${PRIVATE_SDN_INTERFACE} ${node_iip} ${INTERNAL_IP_MASK} "${KUBE_TEMP}/node${i}-network-opts"

    scp-then-execute-expect "${node_ssh_info[$i]}" "${KUBE_TEMP}/node${i}-network-opts ${KUBE_TEMP}/node${i}-host-setup.sh" "~" "\
mkdir -p ~/kube && \
sudo mv ~/node${i}-host-setup.sh ~/kube && \
sudo rm -rf /etc/network/interfaces && sudo mv ~/node${i}-network-opts /etc/network/interfaces && \
sudo ./kube/node${i}-host-setup.sh || \
echo 'Command failed setting up remote host'" & pids="${pids} $!"
  done

  wait-pids "${pids}" "+++++ Wait for all instances to be setup"
}

# A helper function that executes an anchnet command, and retries on failure.
# If the command can't succeed within given attempts, the script will exit directly.
#
# Input:
#   $1 command string to execute
#   $2 number of retries, default to 20
#
# Output:
#   COMMAND_EXEC_RESPONSE response from anchnet command. It is a global variable,
#      so we can't use the function concurrently.
function anchnet-exec-and-retry {
  local attempt=0
  local count=${2-20}
  while true; do
    COMMAND_EXEC_RESPONSE=$(eval $1)
    return_code="$?"
    error_code=$(echo ${COMMAND_EXEC_RESPONSE} | json_val "['code']")
    # Exit if command succeeds but error code is 500.
    if [[ "$return_code" != "0" && "$error_code" == "500" ]]; then
      echo
      echo -e "[`TZ=Asia/Shanghai date`] ${color_red}${color_red}Unable to execute command [$1]: 500 error from anchnet ${COMMAND_EXEC_RESPONSE}${color_norm}" >&2
      kube-up-complete N
      exit 1
    fi
    if [[ "$return_code" != "0" ]]; then
      if (( attempt >= ${count} )); then
        echo
        echo -e "[`TZ=Asia/Shanghai date`] ${color_red}Unable to execute command [$1]: Timeout${color_norm}" >&2
        kube-up-complete N
        exit 1
      fi
    else
      echo -e "[`TZ=Asia/Shanghai date`] ${color_green}Command [$1] ok${color_norm}" >&2
      break
    fi
    echo -e "[`TZ=Asia/Shanghai date`] ${color_yellow}Command [$1] not ok, will retry: ${COMMAND_EXEC_RESPONSE}${color_norm}" >&2
    attempt=$(($attempt+1))
    sleep $(($attempt*2))
  done
}

# Wait until job finishes. If job doesn't finish within timeout, the script
# will exit directly.
#
# Input:
#   $1 anchnet response, typically COMMAND_EXEC_RESPONSE.
#   $2 number of retry, default to 60
#   $3 retry interval, in second, default to 3
function anchnet-wait-job {
  local job_id=$(echo ${1} | json_val '["job_id"]')
  echo -n "[`TZ=Asia/Shanghai date`] Wait until job finishes: ${1} ... "
  ${ANCHNET_CMD} waitjob ${job_id} -c=${2-60} -i=${3-3}
  if [[ "$?" == "0" ]]; then
    echo -e "${color_green}Done${color_norm}"
  else
    echo -e "${color_red}Failed${color_norm}"
    kube-up-complete N
    exit 1
  fi
}

# -----------------------------------------------------------------------------
# Cluster specific test helpers used from hack/e2e-test.sh
# -----------------------------------------------------------------------------
# Perform preparations required to run e2e tests.
function prepare-e2e() {
  ensure-temp-dir

  # Cluster configs for e2e test. Note we must export the variables; otherwise,
  # they won't be visible outside of the function.
  export CLUSTER_NAME="e2e-test"
  export BUILD_TARBALL="Y"
  export KUBE_UP_MODE="tarball"
  export NUM_MINIONS=3
  export MASTER_MEM=2048
  export MASTER_CPU_CORES=2
  export NODE_MEM=2048
  export NODE_CPU_CORES=2
  # This will be used during e2e as ssh user to execute command inside nodes.
  export KUBE_SSH_USER=${KUBE_SSH_USER:-"ubuntu"}
  export KUBECONFIG="$HOME/.kube/config_e2e"

  # Since we changed configs above, we need to re-set cluster env.
  calculate-default

  # As part of e2e preparation, we fix image path.
  ${KUBE_ROOT}/hack/caicloud/k8s-replace.sh
  trap-add '${KUBE_ROOT}/hack/caicloud/k8s-restore.sh' EXIT
}

# Execute prior to running tests to build a release if required for env.
#
# Assumed Vars:
#   KUBE_ROOT
function test-build-release {
  # In e2e test, we will run in tarball mode without specifying version; therefore
  # release will be built during kube-up and we do not need to build release here.
  # Note also, e2e test will test client & server version match. Server binary uses
  # dockerized build; however, developer may use local kubectl (_output/local/bin/kubectl),
  # so we do a local build here.
  log "Anchnet e2e doesn't need pre-build release - release will be built during kube-up"
  anchnet-build-local
}

# Execute prior to running tests to initialize required structure. This is
# called from hack/e2e.go only when running -up (it is ran after kube-up).
#
# Assumed vars:
#   Variables from config.sh
function test-setup {
  log "Anchnet e2e doesn't need special test for setup (after kube-up)"
}

# Execute after running tests to perform any required clean-up. This is called
# from hack/e2e.go
function test-teardown {
  # CLUSTER_NAME should already be set, but we set again to make sure.
  export CLUSTER_NAME="e2e-test"
  kube-down
}
