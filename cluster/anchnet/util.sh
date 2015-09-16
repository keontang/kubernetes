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

# In kube-up.sh, bash is set to exit on error. However, it's very common for
# anchnet cli to return error, and for robustness, we need to retry on error.
# Therefore, we disable errexit here.
set +o errexit

# Path of kubernetes root directory.
KUBE_ROOT="$(dirname "${BASH_SOURCE}")/../.."

# Get cluster configuration parameters from config-default and executor-config.
# config-default is mostly static information configured by caicloud admin, like
# node ip range; while executor-config is mostly dynamic information configured
# by user and executor, like number of nodes, cluster name, etc. Also, retrieve
# executor related methods from executor-service.sh.
function setup-cluster-env {
  source "${KUBE_ROOT}/cluster/anchnet/config-default.sh"
  source "${KUBE_ROOT}/cluster/anchnet/executor-config.sh"
  source "${KUBE_ROOT}/cluster/anchnet/executor-service.sh"
}

setup-cluster-env

# -----------------------------------------------------------------------------
# Cluster specific library utility functions.
# -----------------------------------------------------------------------------
# Step1 of cluster bootstrapping: verify cluster prerequisites.
function verify-prereqs {
  if [[ "$(which anchnet)" == "" ]]; then
    echo "[`TZ=Asia/Shanghai date`] Can't find anchnet cli binary in PATH, please fix and retry."
    echo "[`TZ=Asia/Shanghai date`] See https://github.com/caicloud/anchnet-go/tree/master/anchnet"
    exit 1
  fi
  if [[ "$(which curl)" == "" ]]; then
    echo "[`TZ=Asia/Shanghai date`] Can't find curl in PATH, please fix and retry."
    echo "[`TZ=Asia/Shanghai date`] For ubuntu/debian, if you have root access, run: sudo apt-get install curl."
    exit 1
  fi
  if [[ "$(which expect)" == "" ]]; then
    echo "[`TZ=Asia/Shanghai date`] Can't find expect binary in PATH, please fix and retry."
    echo "[`TZ=Asia/Shanghai date`] For ubuntu/debian, if you have root access, run: sudo apt-get install expect."
    exit 1
  fi
  if [[ "$(which kubectl)" == "" ]]; then
    cd ${KUBE_ROOT}
    hack/build-go.sh
    if [[ "$?" != "0" ]]; then
      echo "[`TZ=Asia/Shanghai date`] Can't find kubectl binary in PATH, please fix and retry."
      exit 1
    fi
    cd -
  fi
  if [[ ! -f "${ANCHNET_CONFIG_FILE}" ]]; then
    echo "[`TZ=Asia/Shanghai date`] Can't find anchnet config file ${ANCHNET_CONFIG_FILE}, please fix and retry."
    echo "[`TZ=Asia/Shanghai date`] Anchnet config file contains credentials used to access anchnet API."
    exit 1
  fi
}


# Step2 of cluster bootstrapping: create all machines and provision them.
function kube-up {
  echo "[`TZ=Asia/Shanghai date`] +++++ Running kube-up with variables ..."
  (set -o posix; set)

  # Check given kube-up mode is supported.
  if [[ ${KUBE_UP_MODE} != "tarball" && ${KUBE_UP_MODE} != "image" && ${KUBE_UP_MODE} != "dev" ]]; then
    echo "[`TZ=Asia/Shanghai date`] Unrecognized kube-up mode ${KUBE_UP_MODE}"
    exit 1
  fi

  # Make sure we have a staging area.
  ensure-temp-dir

  # Make sure we have a public/private key pair used to provision instances.
  ensure-pub-key

  # Make sure log directory exists.
  mkdir -p ${KUBE_INSTANCE_LOGDIR}

  # The following methods generate variables used to provision master and nodes:
  #   NODE_INTERNAL_IPS - comma separated string of node internal ips
  create-node-internal-ips

  # Build tarball if CAICLOUD_KUBE_VERSION is empty; version is based on date/time, e.g.
  # 2015-09-12-10-01
  if [[ "${BUILD_RELEASE}" = "Y" ]]; then
    echo "[`TZ=Asia/Shanghai date`] +++++ Building tarball ..."
    cd ${KUBE_ROOT}
    ./hack/caicloud/build-tarball.sh "${FINAL_VERSION}"
    cd -
  fi

  # For dev, set to existing instance IDs for master and node.
  if [[ "${KUBE_UP_MODE}" = "dev" ]]; then
    MASTER_INSTANCE_ID="i-IWMPEH39"
    NODE_INSTANCE_IDS="i-7C2YH52Q,i-AQFEFGJ1,i-05H5EWY1"
    # To mimic actual kubeup process, we create vars to match create-master-instance
    # create-node-instances, and create-sdn-network.
    #   MASTER_INSTANCE_ID,  MASTER_EIP_ID,  MASTER_EIP
    #   NODE_INSTANCE_IDS,   NODE_EIP_IDS,   NODE_EIPS
    #   PRIVATE_SDN_INTERFACE
    # Also, we override following vars:
    #   NUM_MINIONS, NODE_IIPS
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
    # machines in this network are not set yet, but will be set during provision
    # based on two variables: MASTER_INTERNAL_IP and NODE_INTERNAL_IPS. This method
    # will create one var:
    #   PRIVATE_SDN_INTERFACE - the interface created on each machine for the sdn network.
    create-sdn-network
    # Create firewall rules for all instances.
    create-firewall
  fi

  # Create resource variables used for various provisioning functions.
  #   INSTANCE_IDS, INSTANCE_EIPS, INSTANCE_IIPS
  #   INSTANCE_IDS_ARR, INSTANCE_EIPS_ARR, INSTANCE_IIPS_ARR
  #   NODE_INSTANCE_IDS_ARR, NODE_EIPS_ARR, NODE_IIPS_ARR
  create-resource-variables

  # Create certificates and credentials to secure cluster communication.
  create-certs-and-credentials

  # Setup private SDN network.
  setup-sdn-network

  # Install binaries and packages concurrently
  if [[ "${KUBE_UP_MODE}" != "image" ]]; then
    local pids=""
    install-tarball-binaries & pids="$pids $!"
    install-packages & pids="$pids $!"
    wait $pids
  fi

  # Configure master/nodes instances and start kubernetes.
  provision-instances

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


# Update a kubernetes cluster with latest source.
function kube-push {
  # Find all instances prefixed with CLUSTER_NAME (caicloud convention - every instance
  # is prefixed with a unique CLUSTER_NAME).
  anchnet-exec-and-retry "${ANCHNET_CMD} searchinstance ${CLUSTER_NAME} --project=${PROJECT_ID}"
  local count=$(echo ${COMMAND_EXEC_RESPONSE} | json_len '["item_set"]')

  # Print instance information
  for i in `seq 0 $(($count-1))`; do
    name=$(echo ${COMMAND_EXEC_RESPONSE} | json_val "['item_set'][$i]['instance_name']")
    id=$(echo ${COMMAND_EXEC_RESPONSE} | json_val "['item_set'][$i]['instance_id']")
    echo -n "[`TZ=Asia/Shanghai date`] Found instances: ${name},${id}"
  done
  echo

  # Build server binaries.
  anchnet-build-server

  # Push new binaries to master and nodes.
  echo "[`TZ=Asia/Shanghai date`] +++++ Pushing binaries to master and nodes ..."
  for i in `seq 0 $(($count-1))`; do
    name=$(echo ${COMMAND_EXEC_RESPONSE} | json_val "['item_set'][$i]['instance_name']")
    eip=$(echo ${COMMAND_EXEC_RESPONSE} | json_val "['item_set'][$i]['eip']['eip_addr']")
    if [[ $name == *"master"* ]]; then
      expect <<EOF
set timeout -1
spawn scp -r -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
  ${KUBE_ROOT}/_output/dockerized/bin/linux/amd64/kube-controller-manager \
  ${KUBE_ROOT}/_output/dockerized/bin/linux/amd64/kube-apiserver \
  ${KUBE_ROOT}/_output/dockerized/bin/linux/amd64/kube-scheduler \
  ${INSTANCE_USER}@${eip}:~/kube/master
expect {
  "*?assword:" {
    send -- "${KUBE_INSTANCE_PASSWORD}\r"
    exp_continue
  }
  eof {}
}
EOF
    else
      expect <<EOF
set timeout -1
spawn scp -r -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
  ${KUBE_ROOT}/_output/dockerized/bin/linux/amd64/kubelet \
  ${KUBE_ROOT}/_output/dockerized/bin/linux/amd64/kube-proxy \
  ${INSTANCE_USER}@${eip}:~/kube/node
expect {
  "*?assword:" {
    send -- "${KUBE_INSTANCE_PASSWORD}\r"
    exp_continue
  }
  eof {}
}
EOF
    fi
    if [[ -z "${KUBE_PUSH_ALL_EIPS-}" ]]; then
      KUBE_PUSH_ALL_EIPS="${eip}"
    else
      KUBE_PUSH_ALL_EIPS="${KUBE_PUSH_ALL_EIPS},${eip}"
    fi
  done

  # Stop running cluster.
  IFS=',' read -ra instance_ip_arr <<< "${KUBE_PUSH_ALL_EIPS}"
  echo "[`TZ=Asia/Shanghai date`] +++++ Stop services ..."
  for instance_ip in ${instance_ip_arr[*]}; do
    expect <<EOF
set timeout -1
spawn ssh -t -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
  ${INSTANCE_USER}@${instance_ip} "sudo service etcd stop"
expect {
  "*assword*" {
    send -- "${KUBE_INSTANCE_PASSWORD}\r"
    exp_continue
  }
  eof {}
}
EOF
  done

  # Restart cluster.
  pids=""
  for i in `seq 0 $(($count-1))`; do
    name=$(echo ${COMMAND_EXEC_RESPONSE} | json_val "['item_set'][$i]['instance_name']")
    eip=$(echo ${COMMAND_EXEC_RESPONSE} | json_val "['item_set'][$i]['eip']['eip_addr']")
    if [[ $name == *"master"* ]]; then
      expect <<EOF &
set timeout -1
spawn ssh -t -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
  ${INSTANCE_USER}@${eip} "sudo ~/kube/master-start.sh"
expect {
  "*assword*" {
    send -- "${KUBE_INSTANCE_PASSWORD}\r"
    exp_continue
  }
  eof {}
}
EOF
      pids="$pids $!"
    else
      expect <<EOF &
set timeout -1
spawn ssh -t -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
  ${INSTANCE_USER}@${eip} "sudo ./kube/node-start.sh"
expect {
  "*assword*" {
    send -- "${KUBE_INSTANCE_PASSWORD}\r"
    exp_continue
  }
  eof {}
}
EOF
      pids="$pids $!"
    fi
  done

  echo "[`TZ=Asia/Shanghai date`] +++++ Wait for all instances to be provisioned ..."
  wait $pids
  echo "[`TZ=Asia/Shanghai date`] All instances have been provisioned ..."
}


# Delete a kubernete cluster from anchnet, using CLUSTER_NAME.
#
# Assumed vars:
#   CLUSTER_NAME
#   PROJECT_ID
function kube-down {
  # Find all instances prefixed with CLUSTER_NAME.
  anchnet-exec-and-retry "${ANCHNET_CMD} searchinstance ${CLUSTER_NAME} --project=${PROJECT_ID}"
  count=$(echo ${COMMAND_EXEC_RESPONSE} | json_len '["item_set"]')
  if [[ "${count}" != "" ]]; then
    # Print and collect instance information
    for i in `seq 0 $(($count-1))`; do
      instance_name=$(echo ${COMMAND_EXEC_RESPONSE} | json_val "['item_set'][$i]['instance_name']")
      instance_id=$(echo ${COMMAND_EXEC_RESPONSE} | json_val "['item_set'][$i]['instance_id']")
      eip_id=$(echo ${COMMAND_EXEC_RESPONSE} | json_val "['item_set'][$i]['eip']['eip_id']")
      echo "[`TZ=Asia/Shanghai date`] Found instances: ${instance_name},${instance_id},${eip_id}"
      if [[ -z "${ALL_INSTANCES-}" ]]; then
        ALL_INSTANCES="${instance_id}"
      else
        ALL_INSTANCES="${ALL_INSTANCES},${instance_id}"
      fi
      if [[ -z "${ALL_EIPS-}" ]]; then
        ALL_EIPS="${eip_id}"
      else
        ALL_EIPS="${ALL_EIPS},${eip_id}"
      fi
    done
    # Executing commands.
    anchnet-exec-and-retry "${ANCHNET_CMD} terminateinstances ${ALL_INSTANCES} --project=${PROJECT_ID}"
    anchnet-wait-job ${COMMAND_EXEC_RESPONSE} ${INSTANCE_TERMINATE_WAIT_RETRY} ${INSTANCE_TERMINATE_WAIT_INTERVAL}
    anchnet-exec-and-retry "${ANCHNET_CMD} releaseeips ${ALL_EIPS} --project=${PROJECT_ID}"
    anchnet-wait-job ${COMMAND_EXEC_RESPONSE} ${EIP_RELEASE_WAIT_RETRY} ${EIP_RELEASE_WAIT_INTERVAL}
  fi

  # Find all vxnets prefixed with CLUSTER_NAME.
  anchnet-exec-and-retry "${ANCHNET_CMD} searchvxnets ${CLUSTER_NAME} --project=${PROJECT_ID}"
  count=$(echo ${COMMAND_EXEC_RESPONSE} | json_len '["item_set"]')
  # We'll also find default one - bug in anchnet.
  if [[ "${count}" != "" && "${count}" != "1" ]]; then
    for i in `seq 0 $(($count-1))`; do
      vxnet_name=$(echo ${COMMAND_EXEC_RESPONSE} | json_val "['item_set'][$i]['vxnet_name']")
      vxnet_id=$(echo ${COMMAND_EXEC_RESPONSE} | json_val "['item_set'][$i]['vxnet_id']")
      if [[ "${vxnet_id}" = "vxnet-0" ]]; then
        continue
      fi
      echo "[`TZ=Asia/Shanghai date`] Found vxnets: ${vxnet_name},${vxnet_id}"
      if [[ -z "${ALL_VXNETS-}" ]]; then
        ALL_VXNETS="${vxnet_id}"
      else
        ALL_VXNETS="${ALL_VXNETS},${vxnet_id}"
      fi
    done

    # Executing commands.
    anchnet-exec-and-retry "${ANCHNET_CMD} deletevxnets ${ALL_VXNETS} --project=${PROJECT_ID}"
    anchnet-wait-job ${COMMAND_EXEC_RESPONSE} ${VXNET_DELETE_WAIT_RETRY} ${VXNET_DELETE_WAIT_INTERVAL}
  fi

  # Find all security group prefixed with CLUSTER_NAME.
  anchnet-exec-and-retry "${ANCHNET_CMD} searchsecuritygroup ${CLUSTER_NAME} --project=${PROJECT_ID}"
  count=$(echo ${COMMAND_EXEC_RESPONSE} | json_len '["item_set"]')
  if [[ "${count}" != "" ]]; then
    for i in `seq 0 $(($count-1))`; do
      security_group_name=$(echo ${COMMAND_EXEC_RESPONSE} | json_val "['item_set'][$i]['security_group_name']")
      security_group_id=$(echo ${COMMAND_EXEC_RESPONSE} | json_val "['item_set'][$i]['security_group_id']")
      echo "[`TZ=Asia/Shanghai date`] Found security group: ${security_group_name},${security_group_id}"
      if [[ -z "${ALL_SECURITY_GROUPS-}" ]]; then
        ALL_SECURITY_GROUPS="${security_group_id}"
      else
        ALL_SECURITY_GROUPS="${ALL_SECURITY_GROUPS},${security_group_id}"
      fi
    done

    # Executing commands.
    anchnet-exec-and-retry "${ANCHNET_CMD} deletesecuritygroups ${ALL_SECURITY_GROUPS} --project=${PROJECT_ID}"
    anchnet-wait-job ${COMMAND_EXEC_RESPONSE} ${SG_DELETE_WAIT_RETRY} ${SG_DELETE_WAIT_INTERVAL}
  fi

  # TODO: Find all loadbalancers.
}


# Detect name and IP for kube master.
#
# Assumed vars:
#   MASTER_NAME
#
# Vars set:
#   KUBE_MASTER
#   KUBE_MASTER_IP
function detect-master {
  local attempt=0
  while true; do
    echo "[`TZ=Asia/Shanghai date`] Attempt $(($attempt+1)) to detect kube master"
    echo "[`TZ=Asia/Shanghai date`] $MASTER_NAME"
    local eip=$(${ANCHNET_CMD} searchinstance $MASTER_NAME --project=${PROJECT_ID} | json_val '["item_set"][0]["eip"]["eip_addr"]')
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
  echo "[`TZ=Asia/Shanghai date`] Using master: $KUBE_MASTER (external IP: $KUBE_MASTER_IP)"
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
      ${KUBE_ROOT}/cluster/anchnet/namespace/namespace.yaml \
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
  # Recreate NODE_INTERNAL_IPS since we've chnaged NUM_MINIONS.
  unset NODE_INTERNAL_IPS
  create-node-internal-ips
}


# Create resource variables for followup functions.
function create-resource-variables {
  INSTANCE_IDS="${MASTER_INSTANCE_ID},${NODE_INSTANCE_IDS}"
  INSTANCE_EIPS="${MASTER_EIP},${NODE_EIPS}"
  INSTANCE_IIPS="${MASTER_INTERNAL_IP},${NODE_INTERNAL_IPS}"
  IFS=',' read -ra INSTANCE_IDS_ARR <<< "${INSTANCE_IDS}"
  IFS=',' read -ra INSTANCE_EIPS_ARR <<< "${INSTANCE_EIPS}"
  IFS=',' read -ra INSTANCE_IIPS_ARR <<< "${INSTANCE_IIPS}"
  IFS=',' read -ra NODE_INSTANCE_IDS_ARR <<< "${NODE_INSTANCE_IDS}"
  IFS=',' read -ra NODE_EIPS_ARR <<< "${NODE_EIPS}"
  IFS=',' read -ra NODE_IIPS_ARR <<< "${NODE_INTERNAL_IPS}"
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
    echo "[`TZ=Asia/Shanghai date`] Passwords do not match"
    exit 1
  fi
}


# Create ~/.ssh/id_rsa.pub if it doesn't exist.
function ensure-pub-key {
  if [[ ! -f $HOME/.ssh/id_rsa.pub ]]; then
    echo "[`TZ=Asia/Shanghai date`] +++++++++ Create public key ..."
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
  if [[ -z ${KUBE_USER-} ]]; then
    KUBE_USER=admin
  fi
  if [[ -z ${KUBE_PASSWORD-} ]]; then
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
#   $stdin A json string
#
# Output:
#   stdout: value at given index (empty if error occurs).
#   stderr: any parsing error
function json_val {
  python -c '
import json,sys,datetime,pytz
try:
  obj = json.load(sys.stdin)
  print obj'$1'
except Exception as e:
  timestamp = datetime.datetime.now(pytz.timezone("Asia/Shanghai")).strftime("%a %b %d %H:%M:%S %Z %Y")
  sys.stderr.write("[%s] Unable to parse json string: %s. Please retry\n" % (timestamp, e))
'
}


# Evaluate a json string and return length of required fields. Example:
# $ echo '{"price": [{"item1":12}, {"item2":21}]}' | json_len '["price"]'
# $ 2
#
# Input:
#   $1 A valid string for indexing json string.
#   $stdin A json string
#
# Output:
#   stdout: length at given index (empty if error occurs).
#   stderr: any parsing error
function json_len {
  python -c '
import json,sys,datetime,pytz
try:
  obj = json.load(sys.stdin)
  print len(obj'$1')
except Exception as e:
  timestamp = datetime.datetime.now(pytz.timezone("Asia/Shanghai")).strftime("%a %b %d %H:%M:%S %Z %Y")
  sys.stderr.write("[%s] Unable to parse json string: %s. Please retry\n" % (timestamp, e))
'
}


# Add a top level field in a json file. e.g.:
# $ json_add_field key.json "privatekey" "456"
# {"publickey": "123"} ==> {"publickey": "123", "privatekey": "456"}
#
# Input:
#   $1 Absolute path to the json file
#   $2 Key of the field to be added
#   $3 Value of the field to be added
#
# Output:
#   A top level field gets added to $1
function json_add_field {
  python -c '
import json
with open("'$1'") as f:
  data = json.load(f)
data.update({"'$2'": "'$3'"})
with open("'$1'", "w") as f:
  json.dump(data, f)
'
}


# Create an anchnet project if PROJECT_ID is not specified and report it back
# to executor. Note that we do not create user project if neither PROJECT_ID
# nor KUBE_USER is specified. Also KUBE_USER at this point has not yet been set
# to "admin" (in function get-password), so it's safe to check if it's empty.
#
# Vars set:
#   PROJECT_ID
function create-project {
  if [[ -z "${PROJECT_ID-}" && ! -z "${KUBE_USER-}" ]]; then
    # First try to match if there's any sub account created before.
    anchnet-exec-and-retry "${ANCHNET_CMD} searchuserproject ${KUBE_USER}"
    PROJECT_ID=$(echo ${COMMAND_EXEC_RESPONSE} | json_val "['item_set'][0]['project_id']")
    # If PROJECT_ID is still empty, then create sub account
    if [[ -z "${PROJECT_ID-}" ]]; then
      echo "[`TZ=Asia/Shanghai date`] +++++ Create new anchnet sub account for ${KUBE_USER} ..."
      anchnet-exec-and-retry "${ANCHNET_CMD} createuserproject ${KUBE_USER}"
      anchnet-wait-job ${COMMAND_EXEC_RESPONSE} ${USER_PROJECT_WAIT_RETRY} ${USER_PROJECT_WAIT_INTERVAL}
      PROJECT_ID=$(echo ${COMMAND_EXEC_RESPONSE} | json_val "['api_id']")
      # Get the userId of the sub account. Note the userId here is used internally by
      # anchnet which will be used in tranferring money.
      anchnet-exec-and-retry "${ANCHNET_CMD} describeprojects ${PROJECT_ID}"
      SUB_ACCOUNT_UID=$(echo ${COMMAND_EXEC_RESPONSE} | json_val "['item_set'][0]['userid']")
      # Transfer money from main account to sub-account. We need at least $INITIAL_DEPOSIT
      # to create resources in sub-account.
      echo "[`TZ=Asia/Shanghai date`] +++++ Transferring balance to sub account ..."
      anchnet-exec-and-retry "${ANCHNET_CMD} transfer ${SUB_ACCOUNT_UID} ${INITIAL_DEPOSIT}"
    fi
    report-project-id ${PROJECT_ID}
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
  echo "[`TZ=Asia/Shanghai date`] +++++ Create kubernetes master from anchnet, master name: ${MASTER_NAME} ..."

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

  # Enable ssh without password.
  setup-instance-ssh "${MASTER_EIP}"

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
  echo "[`TZ=Asia/Shanghai date`] +++++ Create kubernetes nodes from anchnet, node name prefix: ${NODE_NAME_PREFIX} ..."

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

    # Enable ssh without password.
    setup-instance-ssh "${node_eip}"

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
    echo "[`TZ=Asia/Shanghai date`] Attempt $(($attempt+1)) to check for instance running"
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
    echo "[`TZ=Asia/Shanghai date`] Attempt $(($attempt+1)) to get eip"
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


# SSH to the machine and put the host's pub key to instance's authorized_key,
# so future ssh commands do not require password to login. Note however,
# if ubuntu is used, we still need to use 'expect' to enter password, because
# root login is disabled by default in ubuntu.
#
# Input:
#   $1 Instance external IP address
#
# Assumed vars:
#   INSTANCE_USER
#   KUBE_INSTANCE_PASSWORD
function setup-instance-ssh {
  attempt=0
  while true; do
    echo "[`TZ=Asia/Shanghai date`] Attempt $(($attempt+1)) to setup instance ssh for $1"
    expect <<EOF
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
    if [[ "$?" != "0" ]]; then
      # We give more attempts for setting up ssh to allow slow instance startup.
      if (( attempt > 40 )); then
        echo
        echo -e "[`TZ=Asia/Shanghai date`] ${color_red}Unable to setup instance ssh for $1 (sorry!)${color_norm}" >&2
        kube-up-complete N
        exit 1
      fi
    else
      echo -e "[`TZ=Asia/Shanghai date`] ${color_green}[ssh to instance working]${color_norm}"
      break
    fi
    # No need to sleep here, we increment timout in expect.
    echo -e "[`TZ=Asia/Shanghai date`] ${color_yellow}[ssh to instance not working yet]${color_norm}"
    attempt=$(($attempt+1))
  done
}


# Wrapper of setup-sdn-network-internal
function setup-sdn-network {
  command-exec-and-retry "setup-sdn-network-internal" 3 "false"
}


# Setup private SDN network.
#
# Assumed vars:
#   MASTER_INTERNAL_IP
#   NODE_INTERNAL_IPS
#   MASTER_EIP
#   NODE_EIPS
function setup-sdn-network-internal {
  # Setup SDN networks for all instances.
  for (( i = 0; i < $(($NUM_MINIONS+1)); i++ )); do
    local instance_iip=${INSTANCE_IIPS_ARR[${i}]}
    local instance_eip=${INSTANCE_EIPS_ARR[${i}]}
    local instance_id=${INSTANCE_IDS_ARR[${i}]}
    create-private-interface-opts ${PRIVATE_SDN_INTERFACE} ${instance_iip} ${INTERNAL_IP_MASK} "${KUBE_TEMP}/network-opts${i}"
    # Setup interface and restart network manager.
    local pids=""
    expect <<EOF >> ${KUBE_INSTANCE_LOGDIR}/${instance_id} &
set timeout -1
spawn scp -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
  ${KUBE_TEMP}/network-opts${i} ${INSTANCE_USER}@${instance_eip}:/tmp/network-opts
expect {
  "*assword*" {
    send -- "${KUBE_INSTANCE_PASSWORD}\r"
    exp_continue
  }
  "lost connection" { exit 1 }
  eof {}
}
spawn ssh -t -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
  ${INSTANCE_USER}@${instance_eip} "\
sudo mv /tmp/network-opts /etc/network/interfaces && \
sudo sed -i 's/^managed=false/managed=true/' /etc/NetworkManager/NetworkManager.conf && \
sudo service network-manager restart"
expect {
  "*assword*" {
    send -- "${KUBE_INSTANCE_PASSWORD}\r"
    exp_continue
  }
  "lost connection" { exit 1 }
  eof {}
}
EOF
    pids="$pids $!"
  done

  echo -n "[`TZ=Asia/Shanghai date`] +++++ Wait for sdn network setup ..."
  local fail=0
  for pid in ${pids}; do
    wait $pid || let "fail+=1"
  done
  if [[ "$fail" == "0" ]]; then
    echo -e "${color_green}Done${color_norm}"
    return 0
  else
    echo -e "${color_red}Failed${color_norm}"
    return 1
  fi
}


# Create a private SDN network in anchnet, then add master and nodes to it. Once
# done, all instances can be reached from preconfigured private IP addresses.
#
# Assumed vars:
#   VXNET_NAME
#
# Vars set:
#   VXNET_ID
#
# Vars set:
#   PRIVATE_SDN_INTERFACE - The interface created by the SDN network
function create-sdn-network {
  echo "[`TZ=Asia/Shanghai date`] +++++ Create private SDN network ..."

  # Create a private SDN network.
  anchnet-exec-and-retry "${ANCHNET_CMD} createvxnets ${CLUSTER_NAME}-${VXNET_NAME} --project=${PROJECT_ID}"
  anchnet-wait-job ${COMMAND_EXEC_RESPONSE} ${VXNET_CREATE_WAIT_RETRY} ${VXNET_CREATE_WAIT_INTERVAL}

  # Get vxnet information.
  local vxnet_info=${COMMAND_EXEC_RESPONSE}
  VXNET_ID=$(echo ${vxnet_info} | json_val '["vxnets"][0]')

  # Add all instances to the vxnet.
  local all_instance_ids="${MASTER_INSTANCE_ID},${NODE_INSTANCE_IDS}"
  echo "[`TZ=Asia/Shanghai date`] Add all instances (both master and nodes) to vxnet ${VXNET_ID} ..."
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
  echo "[`TZ=Asia/Shanghai date`] +++++ Create master security group rules ..."
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
  echo "[`TZ=Asia/Shanghai date`] +++++ Create node security group rules ..."
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
    echo "[`TZ=Asia/Shanghai date`] Number of nodes is larger than allowed node internal IP address"
    kube-up-complete N
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


# Wrapper of install-tarball-binaries-internal.
function install-tarball-binaries {
  command-exec-and-retry "install-tarball-binaries-internal" 2 "false"
}


# Fetch tarball and install binaries to master and nodes, used in tarball mode.
#
# Assumed vars:
#   INSTANCE_USER
#   MASTER_EIP
#   KUBE_INSTANCE_PASSWORD
#   MASTER_INSTANCE_ID
function install-tarball-binaries-internal {
  local pids=""
  local fail=0
  echo "[`TZ=Asia/Shanghai date`] +++++ Start fetching and installing tarball from: ${CAICLOUD_TARBALL_URL}. Log will be saved to ${KUBE_INSTANCE_LOGDIR} ..."

  # Fetch tarball for master node.
  expect <<EOF >> ${KUBE_INSTANCE_LOGDIR}/${MASTER_INSTANCE_ID}
set timeout -1
spawn ssh -t -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
  ${INSTANCE_USER}@${MASTER_EIP} "\
wget ${CAICLOUD_TARBALL_URL} -O ~/caicloud-kube.tar.gz"
expect {
  "*?assword*" {
    send -- "${KUBE_INSTANCE_PASSWORD}\r"
    exp_continue
  }
  "Command failed" {exit 1}
  "lost connection" { exit 1 }
  eof {}
}
EOF

  # Distribute tarball from master to nodes.
  for (( i = 0; i < $(($NUM_MINIONS)); i++ )); do
    local node_internal_ip=${NODE_IIPS_ARR[${i}]}
    local node_instance_id=${NODE_INSTANCE_IDS_ARR[${i}]}
    expect <<EOF >> ${KUBE_INSTANCE_LOGDIR}/${node_instance_id} &
set timeout -1
spawn ssh -t -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
  ${INSTANCE_USER}@${MASTER_EIP} \
"scp -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
  ~/caicloud-kube.tar.gz ${INSTANCE_USER}@${node_internal_ip}:~/caicloud-kube.tar.gz"
expect {
  "*?assword*" {
    send -- "${KUBE_INSTANCE_PASSWORD}\r"
    exp_continue
  }
  "Command failed" {exit 1}
  "lost connection" { exit 1 }
  eof {}
}
EOF
    pids="$pids $!"
  done

  echo -n "[`TZ=Asia/Shanghai date`] +++++ Wait for tarball to be distributed to all nodes ..."
  for pid in ${pids}; do
    wait $pid || let "fail+=1"
  done
  if [[ "$fail" != "0" ]]; then
    echo -e "${color_red}Failed${color_norm}"
    return 1
  fi
  echo -e "${color_green}Done${color_norm}"

  # Extract and install tarball for all instances.
  pids=""
  for (( i = 0; i < $(($NUM_MINIONS+1)); i++ )); do
    local instance_eip=${INSTANCE_EIPS_ARR[${i}]}
    local instance_id=${INSTANCE_IDS_ARR[${i}]}
    expect <<EOF >> ${KUBE_INSTANCE_LOGDIR}/${instance_id} &
set timeout -1
spawn ssh -t -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
  ${INSTANCE_USER}@${instance_eip} "\
tar xvzf caicloud-kube.tar.gz && mkdir -p ~/kube/master && \
cp caicloud-kube/etcd caicloud-kube/etcdctl caicloud-kube/flanneld caicloud-kube/kube-apiserver \
  caicloud-kube/kube-controller-manager caicloud-kube/kubectl caicloud-kube/kube-scheduler ~/kube/master && \
mkdir -p ~/kube/node && \
cp caicloud-kube/etcd caicloud-kube/etcdctl caicloud-kube/flanneld caicloud-kube/kubectl \
  caicloud-kube/kubelet caicloud-kube/kube-proxy ~/kube/node && \
rm -rf caicloud-kube.tar.gz caicloud-kube || \
echo 'Command failed installing tarball binaries on remote host $instance_eip'"
expect {
  "*?assword*" {
    send -- "${KUBE_INSTANCE_PASSWORD}\r"
    exp_continue
  }
  "Command failed" {exit 1}
  "lost connection" { exit 1 }
  eof {}
}
EOF
    pids="$pids $!"
  done

  echo -n "[`TZ=Asia/Shanghai date`] +++++ Wait for all instances to install tarball ..."
  fail=0
  for pid in ${pids}; do
    wait $pid || let "fail+=1"
  done
  if [[ "$fail" == "0" ]]; then
    echo -e "${color_green}Done${color_norm}"
    return 0
  else
    echo -e "${color_red}Failed${color_norm}"
    return 1
  fi
}


# Wrapper of install-packages-internal.
function install-packages {
  command-exec-and-retry "install-packages-internal" 2 "false"
}


# Install necessary packages for running kubernetes. For installing distro
# packages, we use mirrors from 163.com.
#
# Assumed vars:
#   MASTER_EIP
#   NODE_IPS
function install-packages-internal {
  local pids=""
  echo "[`TZ=Asia/Shanghai date`] +++++ Start installing packages. Log will be saved to ${KUBE_INSTANCE_LOGDIR} ..."

  for (( i = 0; i < $(($NUM_MINIONS+1)); i++ )); do
    local instance_eip=${INSTANCE_EIPS_ARR[${i}]}
    local instance_id=${INSTANCE_IDS_ARR[${i}]}
    expect <<EOF >> ${KUBE_INSTANCE_LOGDIR}/${instance_id} &
set timeout -1
spawn scp -r -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
  ${KUBE_ROOT}/hack/caicloud/nsenter ${INSTANCE_USER}@${instance_eip}:~/nsenter
expect {
  "*?assword*" {
    send -- "${KUBE_INSTANCE_PASSWORD}\r"
    exp_continue
  }
  "Command failed" {exit 1}
  "lost connection" { exit 1 }
  eof {}
}
spawn ssh -t -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
  ${INSTANCE_USER}@${instance_eip} "\
sudo sh -c 'echo deb http://mirrors.163.com/ubuntu/ trusty main restricted universe multiverse > /etc/apt/sources.list' && \
sudo sh -c 'echo deb http://mirrors.163.com/ubuntu/ trusty-security main restricted universe multiverse >> /etc/apt/sources.list' && \
sudo sh -c 'echo deb http://mirrors.163.com/ubuntu/ trusty-updates main restricted universe multiverse >> /etc/apt/sources.list' && \
sudo sh -c 'echo deb-src http://mirrors.163.com/ubuntu/ trusty main restricted universe multiverse >> /etc/apt/sources.list' && \
sudo sh -c 'echo deb-src http://mirrors.163.com/ubuntu/ trusty-security main restricted universe multiverse >> /etc/apt/sources.list' && \
sudo sh -c 'echo deb-src http://mirrors.163.com/ubuntu/ trusty-updates main restricted universe multiverse >> /etc/apt/sources.list' && \
sudo sh -c 'echo deb \[arch=amd64\] http://internal-get.caicloud.io/repo ubuntu-trusty main > /etc/apt/sources.list.d/docker.list' && \
sudo mv ~/nsenter /usr/local/bin && \
sudo apt-get update && \
sudo apt-get install --allow-unauthenticated -y docker-engine=${DOCKER_VERSION}-0~trusty && \
sudo apt-get install bridge-utils socat || \
echo 'Command failed installing packages on remote host $instance_eip'"
expect {
  "*?assword*" {
    send -- "${KUBE_INSTANCE_PASSWORD}\r"
    exp_continue
  }
  "Command failed" {exit 1}
  "lost connection" { exit 1 }
  eof {}
}
EOF
    pids="$pids $!"
  done

  echo -n "[`TZ=Asia/Shanghai date`] +++++ Wait for all instances to install packages ..."
  local fail=0
  for pid in ${pids}; do
    wait $pid || let "fail+=1"
  done
  if [[ "$fail" == "0" ]]; then
    echo -e "${color_green}Done${color_norm}"
    return 0
  else
    echo -e "${color_red}Failed${color_norm}"
    return 1
  fi
}


# Wrapper of provision-instances-internal.
function provision-instances {
  command-exec-and-retry "provision-instances-internal" 3 "false"
}


# Configure master/nodes and start them concurrently.
#
# Assumed vars:
#   KUBE_INSTANCE_PASSWORD
#   MASTER_EIP
#   NODE_EIPS
function provision-instances-internal {
  # Install configurations on each node first.
  install-configurations

  local pids=""
  echo "[`TZ=Asia/Shanghai date`] +++++ Start provisioning master and nodes. Log will be saved to ${KUBE_INSTANCE_LOGDIR} ..."
  # Call master-start.sh to start master.
  expect <<EOF >> ${KUBE_INSTANCE_LOGDIR}/${MASTER_INSTANCE_ID} &
set timeout -1
spawn ssh -t -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
  ${INSTANCE_USER}@${MASTER_EIP} "sudo ~/kube/master-start.sh || \
echo 'Command failed provisioning master'"
expect {
  "*?assword*" {
    send -- "${KUBE_INSTANCE_PASSWORD}\r"
    exp_continue
  }
  "Command failed" {exit 1}
  "lost connection" { exit 1 }
  eof {}
}
EOF
  pids="$pids $!"

  for (( i = 0; i < $(($NUM_MINIONS)); i++ )); do
    local node_eip=${NODE_EIPS_ARR[${i}]}
    local node_instance_id=${NODE_INSTANCE_IDS_ARR[${i}]}
    # Call node-start.sh to start node. Note we must run expect in background;
    # otherwise, there will be a deadlock: node0-start.sh keeps retrying for etcd
    # connection (for docker-flannel configuration) because other nodes aren't
    # ready. If we run expect in foreground, we can't start other nodes; thus node0
    # will wait until timeout.
    expect <<EOF >> ${KUBE_INSTANCE_LOGDIR}/${node_instance_id} &
set timeout -1
spawn ssh -t -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
  ${INSTANCE_USER}@${node_eip} "sudo ./kube/node-start.sh || \
echo 'Command failed provisioning node $node_eip'"
expect {
  "*?assword*" {
    send -- "${KUBE_INSTANCE_PASSWORD}\r"
    exp_continue
  }
  "Command failed" {exit 1}
  "lost connection" { exit 1 }
  eof {}
}
EOF
    pids="$pids $!"
  done

  echo -n "[`TZ=Asia/Shanghai date`] +++++ Wait for all instances to be provisioned ..."
  local fail=0
  for pid in ${pids}; do
    wait $pid || let "fail+=1"
  done
  if [[ "$fail" == "0" ]]; then
    echo -e "${color_green}Done${color_norm}"
    return 0
  else
    echo -e "${color_red}Failed${color_norm}"
    return 1
  fi
}


# Wrapper of install-configurations-internal
function install-configurations {
  command-exec-and-retry "install-configurations-internal" 3 "false"
}


# The method assumes instances are running. It does the following things:
# 1. Copies master component configurations to working directory (~/kube).
# 2. Create a master-start.sh file which applies the configs, setup network, and
#   starts k8s master.
# 3. Copies node component configurations to working directory (~/kube).
# 4. Create a node-start.sh file which applies the configs, setup network, and
#   starts k8s node.
#
# Assumed vars:
#   KUBE_ROOT
#   KUBE_TEMP
#   MASTER_EIP
#   MASTER_INTERNAL_IP
#   MASTER_INSTANCE_ID
#   NODE_EIPS
#   NODE_INTERNAL_IPS
#   SERVICE_CLUSTER_IP_RANGE
#   PRIVATE_SDN_INTERFACE
#   DNS_SERVER_IP
#   DNS_DOMAIN
#   POD_INFRA_CONTAINER
function install-configurations-internal {
  local pids=""
  echo "[`TZ=Asia/Shanghai date`] +++++ Start installing master and node configurations. Log will be saved to ${KUBE_INSTANCE_LOGDIR} ..."

  # Create master startup script.
  (
    echo "#!/bin/bash"
    echo "mkdir -p ~/kube/default ~/kube/network ~/kube/security"
    grep -v "^#" "${KUBE_ROOT}/cluster/anchnet/config-default.sh"
    grep -v "^#" "${KUBE_ROOT}/cluster/anchnet/config-components.sh"
    echo ""
    echo "config-hostname ${MASTER_INSTANCE_ID}"
    # Make sure master is able to find nodes using node hostname.
    for (( i = 0; i < ${NUM_MINIONS}; i++ )); do
      echo "add-hosts-entry ${NODE_INSTANCE_IDS_ARR[$i]} ${NODE_IIPS_ARR[$i]}"
    done
    # The following create-*-opts functions create component options (flags).
    # The flag options are stored under ~/kube/default.
    echo "create-etcd-opts kubernetes-master"
    echo "create-kube-apiserver-opts ${SERVICE_CLUSTER_IP_RANGE} ${ADMISSION_CONTROL} ${CLUSTER_NAME}"
    echo "create-kube-controller-manager-opts ${CLUSTER_NAME}"
    echo "create-kube-scheduler-opts"
    echo "create-flanneld-opts ${PRIVATE_SDN_INTERFACE} 127.0.0.1"
    # The following lines organize file structure a little bit. To make it
    # pleasant when running the script multiple times, we ignore errors.
    echo "mv ~/kube/known-tokens.csv ~/kube/basic-auth.csv ~/kube/security 1>/dev/null 2>&1"
    echo "mv ~/kube/ca.crt ~/kube/master.crt ~/kube/master.key ~/kube/security 1>/dev/null 2>&1"
    echo "mv ~/kube/anchnet-config ~/kube/security/anchnet-config 1>/dev/null 2>&1"
    # Create the system directories used to hold the final data.
    echo "sudo mkdir -p /opt/bin"
    echo "sudo mkdir -p /etc/kubernetes"
    # Since we might retry on error, we need to stop services. If no service
    # is running, this is just no-op.
    echo "sudo service etcd stop"
    # Copy binaries and configurations to system directories.
    echo "sudo cp ~/kube/master/* /opt/bin"
    echo "sudo cp ~/kube/default/* /etc/default"
    echo "sudo cp ~/kube/init_conf/* /etc/init/"
    echo "sudo cp ~/kube/init_scripts/* /etc/init.d/"
    echo "sudo cp ~/kube/security/known-tokens.csv ~/kube/security/basic-auth.csv /etc/kubernetes"
    echo "sudo cp ~/kube/security/ca.crt ~/kube/security/master.crt ~/kube/security/master.key /etc/kubernetes"
    echo "sudo cp ~/kube/security/anchnet-config /etc/kubernetes"
    # Finally, start kubernetes cluster. Upstart will make sure all components start
    # upon etcd start.
    echo "sudo service etcd start"
    # After starting etcd, configure flannel options.
    echo "config-etcd-flanneld ${FLANNEL_NET}"
  ) > "${KUBE_TEMP}/master-start.sh"
  chmod a+x ${KUBE_TEMP}/master-start.sh

  # Add a project field in anchnet config file which will be used by k8s cloudprovider
  cp ${ANCHNET_CONFIG_FILE} ${KUBE_TEMP}/anchnet-config
  json_add_field ${KUBE_TEMP}/anchnet-config "projectid" "${PROJECT_ID}"

  # Copy master component configs and startup scripts to master instance under ~/kube.
  scp -r -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
      ${KUBE_ROOT}/cluster/anchnet/master/* \
      ${KUBE_TEMP}/master-start.sh \
      ${KUBE_TEMP}/known-tokens.csv \
      ${KUBE_TEMP}/basic-auth.csv \
      ${KUBE_TEMP}/easy-rsa-master/easyrsa3/pki/ca.crt \
      ${KUBE_TEMP}/easy-rsa-master/easyrsa3/pki/issued/master.crt \
      ${KUBE_TEMP}/easy-rsa-master/easyrsa3/pki/private/master.key \
      ${KUBE_TEMP}/anchnet-config \
      "${INSTANCE_USER}@${MASTER_EIP}":~/kube >> ${KUBE_INSTANCE_LOGDIR}/${MASTER_INSTANCE_ID} &
  pids="$pids $!"

  # Randomly choose one daocloud accelerator.
  IFS=',' read -ra reg_mirror_arr <<< "${DAOCLOUD_ACCELERATOR}"
  reg_mirror=${reg_mirror_arr[$(( ${RANDOM} % 4 ))]}
  echo "[`TZ=Asia/Shanghai date`] Use daocloud registry mirror ${reg_mirror}"

  # Start installing nodes.
  for (( i = 1; i < $(($NUM_MINIONS+1)); i++ )); do
    index=$(($i-1))
    local node_internal_ip=${NODE_IIPS_ARR[${index}]}
    local node_eip=${NODE_EIPS_ARR[${index}]}
    local node_instance_id=${NODE_INSTANCE_IDS_ARR[${index}]}
    # Create node startup script. Note we assume the base image has necessary
    # tools installed, e.g. docker, bridge-util, etc. The flow is similar to
    # master startup script.
    mkdir -p ${KUBE_TEMP}/node${i}
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
      echo "create-kubelet-opts ${node_instance_id} ${node_internal_ip} ${MASTER_INTERNAL_IP} ${DNS_SERVER_IP} ${DNS_DOMAIN} ${POD_INFRA_CONTAINER}"
      echo "create-kube-proxy-opts ${MASTER_INTERNAL_IP}"
      echo "create-flanneld-opts ${PRIVATE_SDN_INTERFACE} ${MASTER_INTERNAL_IP}"
      # Organize files a little bit.
      echo "mv ~/kube/kubelet-kubeconfig ~/kube/kube-proxy-kubeconfig ~/kube/security 1>/dev/null 2>&1"
      echo "mv ~/kube/anchnet-config ~/kube/security/anchnet-config 1>/dev/null 2>&1"
      # Create the system directories used to hold the final data.
      echo "sudo mkdir -p /opt/bin"
      echo "sudo mkdir -p /etc/kubernetes"
      # Since we might retry on error, we need to stop services. If no service
      # is running, this is just no-op.
      echo "sudo service flanneld stop"
      # Copy binaries and configurations to system directories.
      echo "sudo cp ~/kube/node/* /opt/bin"
      echo "sudo cp ~/kube/default/* /etc/default"
      echo "sudo cp ~/kube/init_conf/* /etc/init/"
      echo "sudo cp ~/kube/init_scripts/* /etc/init.d/"
      echo "sudo cp ~/kube/security/kubelet-kubeconfig ~/kube/security/kube-proxy-kubeconfig /etc/kubernetes"
      echo "sudo cp ~/kube/security/anchnet-config /etc/kubernetes"
      # Finally, start kubernetes cluster. Upstart will make sure all components start
      # upon flannel start.
      echo "sudo service flanneld start"
      # After starting flannel, configure docker network to use flannel overlay.
      echo "restart-docker ${reg_mirror}"
    ) > "${KUBE_TEMP}/node${i}/node-start.sh"
    chmod a+x ${KUBE_TEMP}/node${i}/node-start.sh

    # Copy node component configurations and startup script to node instance. The
    # base image we use have the binaries in place.
    scp -r -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
        ${KUBE_ROOT}/cluster/anchnet/node/* \
        ${KUBE_TEMP}/node${i}/node-start.sh \
        ${KUBE_TEMP}/kubelet-kubeconfig \
        ${KUBE_TEMP}/kube-proxy-kubeconfig \
        ${KUBE_TEMP}/anchnet-config \
        "${INSTANCE_USER}@${node_eip}":~/kube >> ${KUBE_INSTANCE_LOGDIR}/${node_instance_id} &
    pids="$pids $!"
  done

  echo -n "[`TZ=Asia/Shanghai date`] +++++ Wait for all configurations to be installed ... "
  local fail=0
  for pid in ${pids}; do
    wait $pid || let "fail+=1"
  done
  if [[ "$fail" == "0" ]]; then
    echo -e "${color_green}Done${color_norm}"
    return 0
  else
    echo -e "${color_red}Failed${color_norm}"
    return 1
  fi
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
  echo "[`TZ=Asia/Shanghai date`] +++++ Create certificats, credentials and secrets ..."

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
    cp "${KUBE_ROOT}/cluster/anchnet/scripts/easy-rsa.tar.gz" "${KUBE_TEMP}"
    cd "${KUBE_TEMP}"
    tar xzf easy-rsa.tar.gz > /dev/null 2>&1
    cd easy-rsa-master/easyrsa3
    ./easyrsa init-pki > /dev/null 2>&1
    ./easyrsa --batch "--req-cn=${MASTER_EIP}@$(date +%s)" build-ca nopass > /dev/null 2>&1
    ./easyrsa --subject-alt-name="${sans}" build-server-full master nopass > /dev/null 2>&1
    ./easyrsa build-client-full kubelet nopass > /dev/null 2>&1
    ./easyrsa build-client-full kubectl nopass > /dev/null 2>&1
  ) || {
    echo "[`TZ=Asia/Shanghai date`] ${color_red}=== Failed to generate certificates: Aborting ===${color_norm}"
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

  # Create tokens for service accounts. 'service_accounts' refers to things that
  # provide services based on apiserver, including scheduler, controller_manager
  # and addons (Note scheduler and controller_manager are not actually used in
  # our setup, but we keep it here for tracking. The reason for having such secrets
  # for these service accounts is to run them as Pod, aka, self-hosting).
  local -r service_accounts=("system:scheduler" "system:controller_manager")
  for account in "${service_accounts[@]}"; do
    token=$(dd if=/dev/urandom bs=128 count=1 2>/dev/null | base64 | tr -d "=+/" | dd bs=32 count=1 2>/dev/null)
    create-kubeconfig-secret "${token}" "${account}" "https://${MASTER_EIP}:${MASTER_SECURE_PORT}" "${KUBE_TEMP}/${account}-secret.yaml"
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


# A helper function that executes a command (or shell function), and retries on
# failure. If the command can't succeed within given attempts, the script will
# exit directly.
#
# Input:
#   $1 command string to execute
#   $2 number of retries, default to 20
function command-exec-and-retry {
  local attempt=0
  local count=${2-20}
  local is_anchnet=${3-"true"}
  while true; do
    eval $1
    if [[ "$?" != "0" ]]; then
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
    echo -e "[`TZ=Asia/Shanghai date`] ${color_yellow}Command [$1] not ok, will retry${color_norm}" >&2
    attempt=$(($attempt+1))
    sleep $(($attempt*2))
  done
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


# Build all binaries using docker. Note there are some restrictions we need
# to fix if the provision host is running in mainland China; it is fixed in
# k8s-replace.sh.
function anchnet-build-release {
  if [[ `uname` == "Darwin" ]]; then
    boot2docker start
  fi
  (
    cd ${KUBE_ROOT}
    hack/caicloud/k8s-replace.sh
    trap '${KUBE_ROOT}/hack/caicloud/k8s-restore.sh' EXIT
    build/release.sh
    cd -
  )
}


# Like build release, but only build server binary (linux amd64).
function anchnet-build-server {
  if [[ `uname` == "Darwin" ]]; then
    boot2docker start
  fi
  (
    cd ${KUBE_ROOT}
    hack/caicloud/k8s-replace.sh
    trap '${KUBE_ROOT}/hack/caicloud/k8s-restore.sh' EXIT
    build/run.sh hack/build-go.sh
    cd -
  )
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
  export BUILD_RELEASE="Y"
  export KUBE_UP_MODE="tarball"
  export NUM_MINIONS=2
  export MASTER_MEM=2048
  export MASTER_CPU_CORES=2
  export NODE_MEM=2048
  export NODE_CPU_CORES=2

  # Since we changed configs above, we need to re-set cluster env.
  setup-cluster-env

  # As part of e2e preparation, we fix image path.
  ${KUBE_ROOT}/hack/caicloud/k8s-replace.sh
  trap '${KUBE_ROOT}/hack/caicloud/k8s-restore.sh' EXIT
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
  echo "[`TZ=Asia/Shanghai date`] Anchnet e2e doesn't need pre-build release - release will be built during kube-up"
  cd ${KUBE_ROOT}
  make clean
  hack/build-go.sh
  cd -
}


# Execute prior to running tests to initialize required structure. This is
# called from hack/e2e.go only when running -up (it is ran after kube-up).
#
# Assumed vars:
#   Variables from config.sh
function test-setup {
  echo "[`TZ=Asia/Shanghai date`] Anchnet e2e doesn't need special test for setup (after kube-up)"
}


# Execute after running tests to perform any required clean-up. This is called
# from hack/e2e.go
function test-teardown {
  # CLUSTER_NAME should already be set, but we set again to make sure.
  export CLUSTER_NAME="e2e-test"
  kube-down
}
