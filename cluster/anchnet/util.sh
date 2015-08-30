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

# KUBE_UP_MODE defines how do we run kube-up, there are currently three modes:
# - "full": In full mode, everything will be built from scratch. Following is
#   the major steps in full mode:
#   1. Clean up the repository and rebuild everything, including client and
#      server kube binaries;
#   2. Fetch non-kube binaries, e.g. etcd, flannel, to localhost. There binaries
#      are hosted at "internal-get.caicloud.io". The official releases are hosted
#      at github.com; however, to make full-mode faster, we download them and
#      host them separately.
#   3. Create instances from anchnet's system image, e.g. trustysrvx64c; then
#      copy all binaries to these instances [can be very slow depending on
#      internet connection].
#   4. Install docker and bridge-utils. Install docker from get.docker.io is
#      slow, so we host our own ubuntu apt mirror on "internal-get.caicloud.io".
#   5. Create other anchnet resources, configure kubernetes, etc. These are
#      the same with other modes.
#
# - "tarball": In tarball mode, we fetch kube binaries and non-kube binaries
#   as a single tarball, instead of building and copying it from localhost. The
#   tarball size is around 40MB, so we host it on qiniu.com, which has better
#   download speed than "internal-get.caicloud.io". (internal-get.caicloud.io
#   is just a file server, while qiniu.com provides a whole stack of storage
#   solution). Tarball mode is faster than full mode, but it's only useful for
#   release, since we can only fetch pre-uploaded tarballs. Using qiniu.com will
#   incur charges, so by default, we download tarball from caicloud; If speed
#   matters, we can use qiniu.com by simply changing TARBALL_URL.
#
# - "image": In image mode, we use pre-built custom image. It is assumed that
#   the custom image has binaries and packages installed, i.e. kube binaries,
#   non-kube binaries, docker, bridge-utils, etc. Image mode is the fastest of
#   the above three modes, but requires we pre-built the image and requires the
#   image to be accessible when running kube-up. This is currently not possible
#   in anchnet, since every account can only see its own custom image.
#
# - "dev": In dev mode, no machine will be created. Developer is responsible to
#   specify the instance IDs, eip IDs, etc. This is primarily used for debugging.
KUBE_UP_MODE=${KUBE_UP_MODE:-"tarball"}

# Non-kube binaries versions
# == This is Full Mode specific parameter.
FLANNEL_VERSION=${FLANNEL_VERSION:-0.4.0}
ETCD_VERSION=${ETCD_VERSION:-v2.0.12}

# Package version.
# == This is Full and Tarball Mode specific parameter.
DOCKER_VERSION=${DOCKER_VERSION:-1.7.1}

# Tarball URL.
# == This is Tarball mode specific parameter.
# TARBALL_URL=${TARBALL_URL:-"http://internal-get.caicloud.io/caicloud/caicloud-kube-release-0.1.tar.gz"}
TARBALL_URL=${TARBALL_URL:-"http://7xl0eo.com1.z0.glb.clouddn.com/caicloud-kube-release-0.1.tar.gz"}

# The base image used to create master and node instance in image mode. This
# image is created from scripts like 'image-from-devserver.sh'.
# == This is Image Mode specific parameter.
INSTANCE_IMAGE=${INSTANCE_IMAGE:-"img-C0SA7DD5"}

# Instance user and password.
INSTANCE_USER=${INSTANCE_USER:-"ubuntu"}
KUBE_INSTANCE_PASSWORD=${KUBE_INSTANCE_PASSWORD:-"caicloud2015ABC"}

# The IP Group used for new instances. 'eipg-98dyd0aj' is China Telecom and
# 'eipg-00000000' is anchnet's own BGP.
IP_GROUP=${IP_GROUP:-"eipg-00000000"}

# Anchnet config file to use.
ANCHNET_CONFIG_FILE=${ANCHNET_CONFIG_FILE:-"$HOME/.anchnet/config"}

# Namespace used to create cluster wide services.
SYSTEM_NAMESPACE=${SYSTEM_NAMESPACE-"kube-system"}

# USER_ID uniquely identifies a caicloud user
USER_ID=${USER_ID:-""}

# Project id actually stands for an anchnet sub-account. If PROJECT_ID is
# not set, all the subsequent anchnet calls will use the default account
PROJECT_ID=${PROJECT_ID:-""}

# To indicate if the execution status needs to be reported back to Caicloud
# executor via curl. Set it to be Y if reporting is needed.
REPORT_KUBE_STATUS=${REPORT_KUBE_STATUS-"N"}
source "${KUBE_ROOT}/cluster/anchnet/executor_service.sh"

# Daocloud registry accelerator. Before implementing our own registry (or registry
# mirror), use this accelerator to make pulling image faster. The variable is a
# comma separated list of mirror address, we randomly choose one of them.
#   http://47178212.m.daocloud.io -> deyuan.deng@gmail.com
#   http://dd69bd44.m.daocloud.io -> 729581241@qq.com
#   http://9482cd22.m.daocloud.io -> dalvikbogus@gmail.com
#   http://4a682d3b.m.daocloud.io -> 492886102@qq.com
DAOCLOUD_ACCELERATOR="http://47178212.m.daocloud.io,http://dd69bd44.m.daocloud.io,\
http://9482cd22.m.daocloud.io,http://4a682d3b.m.daocloud.io"

# Helper constants.
ANCHNET_CMD="anchnet --config-path=${ANCHNET_CONFIG_FILE}"
CURL_CMD="curl"
EXPECT_CMD="expect"
BASE_IMAGE="trustysrvx64c"
if [[ "${KUBE_UP_MODE}" == "full" || "${KUBE_UP_MODE}" == "tarball" ]]; then
  INSTANCE_IMAGE=${BASE_IMAGE} # Use base image from anchnet in full and tarball mode.
fi

# Get all cluster configuration parameters from config-default and user-config.
# config-default is mostly static information configured by caicloud admin, like
# node ip range; while user-config is configured by user, like number of nodes.
# We also create useful vars based on config information:
#   MASTER_NAME, NODE_NAME_PREFIX
# Note that master_name and node_name are name of the instances in anchnet, which
# is helpful to group instances; however, anchnet API works well with instance id,
# so we provide instance id to kubernetes as nodename and hostname, which makes it
# easy to query anchnet in kubernetes.
function setup-anchnet-env {
  USER_CONFIG_FILE=${USER_CONFIG_FILE:-"${KUBE_ROOT}/cluster/anchnet/default-user-config.sh"}
  source "${KUBE_ROOT}/cluster/anchnet/config-default.sh"
  source "${USER_CONFIG_FILE}"
  MASTER_NAME="${CLUSTER_ID}-master"
  NODE_NAME_PREFIX="${CLUSTER_ID}-node"
}

# Before running any function, we setup all anchnet env variables.
setup-anchnet-env


# -----------------------------------------------------------------------------
# Cluster specific library utility functions.

# Step1 of cluster bootstrapping: verify cluster prerequisites.
function verify-prereqs {
  if [[ "$(which anchnet)" == "" ]]; then
    echo "Can't find anchnet cli binary in PATH, please fix and retry."
    echo "See https://github.com/caicloud/anchnet-go/tree/master/anchnet"
    exit 1
  fi
  if [[ "$(which curl)" == "" ]]; then
    echo "Can't find curl in PATH, please fix and retry."
    echo "For ubuntu/debian, if you have root access, run: sudo apt-get install curl."
    exit 1
  fi
  if [[ "$(which expect)" == "" ]]; then
    echo "Can't find expect binary in PATH, please fix and retry."
    echo "For ubuntu/debian, if you have root access, run: sudo apt-get install expect."
    exit 1
  fi
  if [[ "$(which kubectl)" == "" ]]; then
    (
      cd ${KUBE_ROOT}
      hack/build-go.sh
      if [[ "$?" != "0" ]]; then
        echo "Can't find kubectl binary in PATH, please fix and retry."
        exit 1
      fi
      cd -
    )
  fi
  if [[ ! -f "${ANCHNET_CONFIG_FILE}" ]]; then
    echo "Can't find anchnet config file ${ANCHNET_CONFIG_FILE}, please fix and retry."
    echo "Anchnet config file contains credentials used to access anchnet API."
    exit 1
  fi
}


# Step2 of cluster bootstrapping: create all machines and provision them.
function kube-up {
  # Make sure we have a staging area.
  ensure-temp-dir

  # Make sure we have a public/private key pair used to provision instances.
  ensure-pub-key

  # Create an anchnet project if projectid is not set and report
  # it back to executor.
  # TODO: PROJECT_ID creation is dummy for now. This will be replaced
  # with anchnet api call to dynamically create sub account
  if [[ -z ${PROJECT_ID-} ]]; then
      PROJECT_ID="pro-PAHG3JWF"
      report-project-id ${PROJECT_ID}
  fi

  # For dev, set to existing instances.
  if [[ "${KUBE_UP_MODE}" = "dev" ]]; then
    MASTER_INSTANCE_ID="i-8DRF060F"
    MASTER_EIP_ID="eip-1BG18SPI"
    MASTER_EIP="43.254.54.196"
    NODE_INSTANCE_IDS="i-LKC0Y64C,i-S8Q6V8YG"
    NODE_EIP_IDS="eip-WO4BB47Y,eip-91WBNBM1"
    NODE_EIPS="43.254.55.53,43.254.55.92"
    PRIVATE_SDN_INTERFACE="eth1"
  else
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

  local pids=""
  if [[ "${KUBE_UP_MODE}" = "full" ]]; then
    install-all-binaries &
    pids="$pids $!"
    install-packages &
    pids="$pids $!"
  fi

  if [[ "${KUBE_UP_MODE}" = "tarball" ]]; then
    install-tarball-binaries &
    pids="$pids $!"
    install-packages &
    pids="$pids $!"
  fi
  wait $pids

  # Create certificates and credentials to secure cluster communication.
  create-certs-and-credentials
  # The following methods generate variables used to provision master and nodes:
  #   NODE_INTERNAL_IPS - comma separated string of node internal ips
  #   ETCD_INITIAL_CLUSTER - flag etcd_init_cluster passsed to etcd instance
  create-node-internal-ips
  create-etcd-initial-cluster

  # Configure master/nodes instances and start kubernetes.
  provision-instances

  # After everything's done, we re-apply firewall to make sure it works.
  ensure-firewall

  # common.sh defines create-kubeconfig, which is used to create client kubeconfig for
  # kubectl. To properly create kubeconfig, make sure to we supply it with assumed vars.
  source "${KUBE_ROOT}/cluster/common.sh"
  # By default, kubeconfig uses https://${KUBE_MASTER_IP}. Since we use standard port 443,
  # just assign MASTER_EIP to KUBE_MASTER_EIP. If non-standard port is used, then we need
  # to set KUBE_MASTER_IP="${MASTER_EIP}:${MASTER_SECURE_PORT}"
  KUBE_MASTER_IP="${MASTER_EIP}"
  # TODO: Fix hardcoded CONTEXT
  CONTEXT="anchnet_kubernetes"
  create-kubeconfig
}


# Update a kubernetes cluster with latest source.
function kube-push {
  # Find all instances prefixed with CLUSTER_ID (caicloud convention - every instance
  # is prefixed with a unique CLUSTER_ID).
  anchnet-exec-and-retry "${ANCHNET_CMD} searchinstance ${CLUSTER_ID} --project=${PROJECT_ID}"
  local count=$(echo ${ANCHNET_RESPONSE} | json_len '["item_set"]')

  # Print instance information
  echo -n "Found instances: "
  for i in `seq 0 $(($count-1))`; do
    name=$(echo ${ANCHNET_RESPONSE} | json_val "['item_set'][$i]['instance_name']")
    id=$(echo ${ANCHNET_RESPONSE} | json_val "['item_set'][$i]['instance_id']")
    echo -n "${name},${id}; "
  done
  echo

  # Build server binaries.
  anchnet-build-server

  # Push new binaries to master and nodes.
  echo "++++++++++ Pushing binaries to master and nodes ..."
  for i in `seq 0 $(($count-1))`; do
    name=$(echo ${ANCHNET_RESPONSE} | json_val "['item_set'][$i]['instance_name']")
    eip=$(echo ${ANCHNET_RESPONSE} | json_val "['item_set'][$i]['eip']['eip_addr']")
    if [[ $name == *"master"* ]]; then
      ${EXPECT_CMD} <<EOF
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
      ${EXPECT_CMD} <<EOF
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
  echo "++++++++++ Stop services ..."
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
    name=$(echo ${ANCHNET_RESPONSE} | json_val "['item_set'][$i]['instance_name']")
    eip=$(echo ${ANCHNET_RESPONSE} | json_val "['item_set'][$i]['eip']['eip_addr']")
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

  echo "Wait for all instances to be provisioned ..."
  wait $pids
  echo "All instances have been provisioned ..."
}


# Delete a kubernete cluster from anchnet, using CLUSTER_ID.
#
# Assumed vars:
#   CLUSTER_ID
function kube-down {
  # Find all instances prefixed with CLUSTER_ID.
  anchnet-exec-and-retry "${ANCHNET_CMD} searchinstance ${CLUSTER_ID} --project=${PROJECT_ID}"
  count=$(echo ${ANCHNET_RESPONSE} | json_len '["item_set"]')
  if [[ "${count}" != "" ]]; then
    # Print and collect instance information
    echo -n "Found instances: "
    for i in `seq 0 $(($count-1))`; do
      instance_name=$(echo ${ANCHNET_RESPONSE} | json_val "['item_set'][$i]['instance_name']")
      instance_id=$(echo ${ANCHNET_RESPONSE} | json_val "['item_set'][$i]['instance_id']")
      eip_id=$(echo ${ANCHNET_RESPONSE} | json_val "['item_set'][$i]['eip']['eip_id']")
      echo -n "${instance_name},${instance_id},${eip_id}; "
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
    echo
    # Executing commands.
    anchnet-exec-and-retry "${ANCHNET_CMD} terminateinstances ${ALL_INSTANCES} --project=${PROJECT_ID}"
    anchnet-wait-job ${ANCHNET_RESPONSE} 240 6
    anchnet-exec-and-retry "${ANCHNET_CMD} releaseeips ${ALL_EIPS} --project=${PROJECT_ID}"
    anchnet-wait-job ${ANCHNET_RESPONSE} 240 6
  fi

  # Find all vxnets prefixed with CLUSTER_ID.
  anchnet-exec-and-retry "${ANCHNET_CMD} searchvxnets ${CLUSTER_ID} --project=${PROJECT_ID}"
  count=$(echo ${ANCHNET_RESPONSE} | json_len '["item_set"]')
  # We'll also find default one - bug in anchnet.
  if [[ "${count}" != "" && "${count}" != "1" ]]; then
    echo -n "Found vxnets: "
    for i in `seq 0 $(($count-1))`; do
      vxnet_name=$(echo ${ANCHNET_RESPONSE} | json_val "['item_set'][$i]['vxnet_name']")
      vxnet_id=$(echo ${ANCHNET_RESPONSE} | json_val "['item_set'][$i]['vxnet_id']")
      if [[ "${vxnet_id}" = "vxnet-0" ]]; then
        continue
      fi
      echo -n "${vxnet_name},${vxnet_id}; "
      if [[ -z "${ALL_VXNETS-}" ]]; then
        ALL_VXNETS="${vxnet_id}"
      else
        ALL_VXNETS="${ALL_VXNETS},${vxnet_id}"
      fi
    done
    echo

    # Executing commands.
    anchnet-exec-and-retry "${ANCHNET_CMD} deletevxnets ${ALL_VXNETS} --project=${PROJECT_ID}"
    anchnet-wait-job ${ANCHNET_RESPONSE} 240 6
  fi

  # Find all security group prefixed with CLUSTER_ID.
  anchnet-exec-and-retry "${ANCHNET_CMD} searchsecuritygroup ${CLUSTER_ID} --project=${PROJECT_ID}"
  count=$(echo ${ANCHNET_RESPONSE} | json_len '["item_set"]')
  if [[ "${count}" != "" ]]; then
    echo -n "Found security group: "
    for i in `seq 0 $(($count-1))`; do
      security_group_name=$(echo ${ANCHNET_RESPONSE} | json_val "['item_set'][$i]['security_group_name']")
      security_group_id=$(echo ${ANCHNET_RESPONSE} | json_val "['item_set'][$i]['security_group_id']")
      echo -n "${security_group_name},${security_group_id}; "
      if [[ -z "${ALL_SECURITY_GROUPS-}" ]]; then
        ALL_SECURITY_GROUPS="${security_group_id}"
      else
        ALL_SECURITY_GROUPS="${ALL_SECURITY_GROUPS},${security_group_id}"
      fi
    done
    echo

    # Executing commands.
    anchnet-exec-and-retry "${ANCHNET_CMD} deletesecuritygroups ${ALL_SECURITY_GROUPS} --project=${PROJECT_ID}"
    anchnet-wait-job ${ANCHNET_RESPONSE} 240 6
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
    echo "Attempt $(($attempt+1)) to detect kube master"
    echo "$MASTER_NAME"
    local eip=$(${ANCHNET_CMD} searchinstance $MASTER_NAME --project=${PROJECT_ID} | json_val '["item_set"][0]["eip"]["eip_addr"]')
    local exit_code="$?"
    echo ${eip}
    if [[ "${exit_code}" != "0" || ! ${eip} =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
      if (( attempt > 20 )); then
        echo
        echo -e "${color_red}failed to detect kube master (sorry!)${color_norm}" >&2
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
  echo "Using master: $KUBE_MASTER (external IP: $KUBE_MASTER_IP)"
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
  ${EXPECT_CMD} <<EOF
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
  if [[ ! -f $HOME/.ssh/id_rsa.pub ]]; then
    echo "+++++++++ Creating public key ..."
    ${EXPECT_CMD} <<EOF
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
#   $stdin A json string
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
import json,sys
try:
  obj=json.load(sys.stdin)
  print len(obj'$1')
except:
  sys.stderr.write("Unable to parse json string, please retry\n")
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
  echo "++++++++++ Creating kubernetes master from anchnet, master name: ${MASTER_NAME} ..."

  # Create a 'raw' master instance from anchnet, i.e. un-provisioned.
  anchnet-exec-and-retry "${ANCHNET_CMD} runinstance ${MASTER_NAME} \
-p=${KUBE_INSTANCE_PASSWORD} -i=${INSTANCE_IMAGE} -m=${MASTER_MEM} \
-c=${MASTER_CPU_CORES} -g=${IP_GROUP} --project=${PROJECT_ID}"
  anchnet-wait-job ${ANCHNET_RESPONSE} 120 3

  # Get master information.
  local master_info=${ANCHNET_RESPONSE}
  MASTER_INSTANCE_ID=$(echo ${master_info} | json_val '["instances"][0]')
  MASTER_EIP_ID=$(echo ${master_info} | json_val '["eips"][0]')

  # Check instance status and its external IP address.
  check-instance-status "${MASTER_INSTANCE_ID}"
  get-ip-address-from-eipid "${MASTER_EIP_ID}"
  MASTER_EIP=${EIP_ADDRESS}

  # Enable ssh without password.
  setup-instance-ssh "${MASTER_EIP}"

  echo -e " ${color_green}[created master with instance ID ${MASTER_INSTANCE_ID}, \
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
  echo "++++++++++ Creating kubernetes nodes from anchnet, node name prefix: ${NODE_NAME_PREFIX} ..."

  # Create 'raw' node instances from anchnet, i.e. un-provisioned.
  anchnet-exec-and-retry "${ANCHNET_CMD} runinstance ${NODE_NAME_PREFIX} \
-p=${KUBE_INSTANCE_PASSWORD} -i=${INSTANCE_IMAGE} -m=${NODE_MEM} \
-c=${NODE_CPU_CORES} -g=${IP_GROUP} -a=${NUM_MINIONS} --project=${PROJECT_ID}"
  anchnet-wait-job ${ANCHNET_RESPONSE} 240 3

  # Node name starts from 1.
  for (( i = 1; i < $(($NUM_MINIONS+1)); i++ )); do
    # Get node information.
    local node_info=${ANCHNET_RESPONSE}
    local node_instance_id=$(echo ${node_info} | json_val "['instances'][$(($i-1))]")
    local node_eip_id=$(echo ${node_info} | json_val "['eips'][$(($i-1))]")

    # Check instance status and its external IP address.
    check-instance-status "${node_instance_id}"
    get-ip-address-from-eipid "${node_eip_id}"
    local node_eip=${EIP_ADDRESS}

    # Enable ssh without password.
    setup-instance-ssh "${node_eip}"

    echo -e " ${color_green}[created node-${i} with instance ID ${node_instance_id}, \
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

  echo -e " ${color_green}[Created cluster nodes with instance IDs ${NODE_INSTANCE_IDS}, \
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
    echo "Attempt $(($attempt+1)) to check for instance running"
    local status=$(${ANCHNET_CMD} describeinstance $1 --project=${PROJECT_ID} | json_val '["item_set"][0]["status"]')
    if [[ ${status} != "running" ]]; then
      if (( attempt > 20 )); then
        echo
        echo -e "${color_red}instance $1 failed to start (sorry!)${color_norm}" >&2
        exit 1
      fi
    else
      echo -e " ${color_green}[instance $1 becomes running status]${color_norm}"
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
    local eip=$(${ANCHNET_CMD} describeeips $1 --project=${PROJECT_ID} | json_val '["item_set"][0]["eip_addr"]')
    # Test the return value roughly matches ipv4 format.
    if [[ ! ${eip} =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
      if (( attempt > 20 )); then
        echo
        echo -e "${color_red}failed to get eip address (sorry!)${color_norm}" >&2
        exit 1
      fi
    else
      EIP_ADDRESS=${eip}
      echo -e " ${color_green}[get eip address ${EIP_ADDRESS} for $1]${color_norm}"
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
    echo "Attempt $(($attempt+1)) to setup instance ssh for $1"
    ${EXPECT_CMD} <<EOF
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
#   VXNET_ID
#
# Vars set:
#   PRIVATE_SDN_INTERFACE - The interface created by the SDN network
function create-sdn-network {
  echo "++++++++++ Creating private SDN network ..."

  # Create a private SDN network.
  anchnet-exec-and-retry "${ANCHNET_CMD} createvxnets ${CLUSTER_ID}-${VXNET_NAME} --project=${PROJECT_ID}"
  anchnet-wait-job ${ANCHNET_RESPONSE}

  # Get vxnet information.
  local vxnet_info=${ANCHNET_RESPONSE}
  VXNET_ID=$(echo ${vxnet_info} | json_val '["vxnets"][0]')

  # Add all instances to the vxnet.
  local all_instance_ids="${MASTER_INSTANCE_ID},${NODE_INSTANCE_IDS}"
  echo "Add all instances (both master and nodes) to vxnet ${VXNET_ID} ..."
  anchnet-exec-and-retry "${ANCHNET_CMD} joinvxnet ${VXNET_ID} ${all_instance_ids} --project=${PROJECT_ID}"
  anchnet-wait-job ${ANCHNET_RESPONSE}

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
  echo "++++++++++ Creating master security group rules ..."
  anchnet-exec-and-retry "${ANCHNET_CMD} createsecuritygroup ${CLUSTER_ID}-${MASTER_SG_NAME} \
--rulename=master-ssh,master-https --priority=1,2 --action=accept,accept --protocol=tcp,tcp \
--direction=0,0 --value1=22,${MASTER_SECURE_PORT} --value2=22,${MASTER_SECURE_PORT} --project=${PROJECT_ID}"
  anchnet-wait-job ${ANCHNET_RESPONSE} 120 3

  # Get security group information.
  local master_sg_info=${ANCHNET_RESPONSE}
  MASTER_SG_ID=$(echo ${master_sg_info} | json_val '["security_group_id"]')

  # Now, apply all above changes.
  report-security-group-ids ${MASTER_SG_ID} M
  anchnet-exec-and-retry "${ANCHNET_CMD} applysecuritygroup ${MASTER_SG_ID} ${MASTER_INSTANCE_ID} --project=${PROJECT_ID}"
  anchnet-wait-job ${ANCHNET_RESPONSE}

  #
  # Node security group contains firewall for ssh (tcp/22) and nodeport range
  # (tcp/30000-32767, udp/30000-32767).
  #
  echo "++++++++++ Creating node security group rules ..."
  anchnet-exec-and-retry "${ANCHNET_CMD} createsecuritygroup ${CLUSTER_ID}-${NODE_SG_NAME} \
--rulename=node-ssh,nodeport-range-tcp,nodeport-range-udp --priority=1,2,3 \
--action=accept,accept,accept --protocol=tcp,tcp,udp --direction=0,0,0 \
--value1=22,30000,30000 --value2=22,32767,32767 --project=${PROJECT_ID}"
  anchnet-wait-job ${ANCHNET_RESPONSE} 120 3

  # Get security group information.
  local node_sg_info=${ANCHNET_RESPONSE}
  NODE_SG_ID=$(echo ${node_sg_info} | json_val '["security_group_id"]')

  # Now, apply all above changes.
  report-security-group-ids ${NODE_SG_ID} N
  anchnet-exec-and-retry "${ANCHNET_CMD} applysecuritygroup ${NODE_SG_ID} ${NODE_INSTANCE_IDS} --project=${PROJECT_ID}"
  anchnet-wait-job ${ANCHNET_RESPONSE}
}


# Re-apply firewall to make sure firewall is properly set up.
function ensure-firewall {
  anchnet-exec-and-retry "${ANCHNET_CMD} applysecuritygroup ${MASTER_SG_ID} ${MASTER_INSTANCE_ID} --project=${PROJECT_ID}"
  anchnet-exec-and-retry "${ANCHNET_CMD} applysecuritygroup ${NODE_SG_ID} ${NODE_INSTANCE_IDS} --project=${PROJECT_ID}"
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
  for (( i = 1; i < $(($NUM_MINIONS+1)); i++ )); do
    node_internal_ip="${node_iip_arr[$(($i-1))]}"
    ETCD_INITIAL_CLUSTER="$ETCD_INITIAL_CLUSTER,kubernetes-node-${i}=http://${node_internal_ip}:2380"
  done
}


# Push new binaries to master and nodes.
#
# Assumed vars:
#   KUBE_ROOT
#   MASTER_IP
#   NODE_IPS
#   INSTANCE_USER
#   KUBE_INSTANCE_PASSWORD
function install-all-binaries {
  echo "++++++++++ Start installing all binaries ..."
  (
    cd ${KUBE_ROOT}
    anchnet-build-server
    IFS=',' read -ra instance_ip_arr <<< "${MASTER_EIP},${NODE_EIPS}"

    # Fetch etcd and flanneld.
    (
      cd ${KUBE_TEMP}
      wget http://internal-get.caicloud.io/etcd/etcd-$ETCD_VERSION-linux-amd64.tar.gz -O etcd-linux.tar.gz
      mkdir -p etcd-linux && tar xzf etcd-linux.tar.gz -C etcd-linux --strip-components=1
      mv etcd-linux/etcd etcd-linux/etcdctl .
      wget http://internal-get.caicloud.io/flannel/flannel-$FLANNEL_VERSION-linux-amd64.tar.gz -O flannel-linux.tar.gz
      mkdir -p flannel-linux && tar xzf flannel-linux.tar.gz -C flannel-linux --strip-components=1
      mv flannel-linux/flanneld .
      cd -
    )

    # Copy master binaries.
    ${EXPECT_CMD} <<EOF
set timeout -1
spawn ssh -t -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
  ${INSTANCE_USER}@${MASTER_EIP} "mkdir -p ~/kube/master ~/kube/node"
expect {
  "*?assword*" {
    send -- "${KUBE_INSTANCE_PASSWORD}\r"
    exp_continue
  }
  eof {}
}
EOF
    ${EXPECT_CMD} <<EOF
set timeout -1
spawn scp -r -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
  ${KUBE_ROOT}/_output/dockerized/bin/linux/amd64/kube-controller-manager \
  ${KUBE_ROOT}/_output/dockerized/bin/linux/amd64/kube-apiserver \
  ${KUBE_ROOT}/_output/dockerized/bin/linux/amd64/kube-scheduler \
  ${KUBE_ROOT}/_output/dockerized/bin/linux/amd64/kubectl \
  ${KUBE_TEMP}/etcd ${KUBE_TEMP}/etcdctl ${KUBE_TEMP}/flanneld \
  ${INSTANCE_USER}@${MASTER_EIP}:~/kube/master
expect {
  "*?assword:" {
    send -- "${KUBE_INSTANCE_PASSWORD}\r"
    exp_continue
  }
  eof {}
}
EOF

    # Copy node binaries.
    IFS=',' read -ra node_ip_arr <<< "${NODE_EIPS}"

    for node_ip in ${node_ip_arr[*]}; do
      ${EXPECT_CMD} <<EOF
set timeout -1
spawn ssh -t -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
  ${INSTANCE_USER}@${node_ip} "mkdir -p ~/kube/master ~/kube/node"
expect {
  "*?assword*" {
    send -- "${KUBE_INSTANCE_PASSWORD}\r"
    exp_continue
  }
  eof {}
}
EOF
      ${EXPECT_CMD} <<EOF
set timeout -1
spawn scp -r -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
  ${KUBE_ROOT}/_output/dockerized/bin/linux/amd64/kubelet \
  ${KUBE_ROOT}/_output/dockerized/bin/linux/amd64/kubectl \
  ${KUBE_ROOT}/_output/dockerized/bin/linux/amd64/kube-proxy \
  ${KUBE_TEMP}/etcd ${KUBE_TEMP}/etcdctl ${KUBE_TEMP}/flanneld \
  ${INSTANCE_USER}@${node_ip}:~/kube/node
expect {
  "*?assword:" {
    send -- "${KUBE_INSTANCE_PASSWORD}\r"
    exp_continue
  }
  eof {}
}
EOF
    done

    cd -
  )
}


# Fetch tarball and install binaries to master and nodes, used in tarball mode.
#
# Assumed vars:
#   INSTANCE_USER
#   MASTER_EIP
#   KUBE_INSTANCE_PASSWORD
function install-tarball-binaries {
  local pids=""
  echo "++++++++++ Start fetching and installing tarball ..."

  INSTANCE_EIPS="${MASTER_EIP},${NODE_EIPS}"
  IFS=',' read -ra instance_eip_arr <<< "${INSTANCE_EIPS}"
  for instance_eip in ${instance_eip_arr[*]}; do
    ${EXPECT_CMD} <<EOF &
set timeout -1
spawn ssh -t -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
  ${INSTANCE_USER}@${instance_eip} "\
wget ${TARBALL_URL} -O caicloud-kube.tar.gz && tar xvzf caicloud-kube.tar.gz && \
mkdir -p ~/kube/master && \
cp caicloud-kube/etcd caicloud-kube/etcdctl caicloud-kube/flanneld caicloud-kube/kube-apiserver \
  caicloud-kube/kube-controller-manager caicloud-kube/kubectl caicloud-kube/kube-scheduler ~/kube/master && \
mkdir -p ~/kube/node && \
cp caicloud-kube/etcd caicloud-kube/etcdctl caicloud-kube/flanneld caicloud-kube/kubectl \
  caicloud-kube/kubelet caicloud-kube/kube-proxy ~/kube/node"
expect {
  "*?assword*" {
    send -- "${KUBE_INSTANCE_PASSWORD}\r"
    exp_continue
  }
  eof {}
}
EOF
    pids="$pids $!"
  done

  echo "Wait for all instances to fetch and install tarball ..."
  wait $pids
  echo "All instances finished installing tarball ..."
}


# Install necessary packages for running kubernetes.
#
# Assumed vars:
#   MASTER_EIP
#   NODE_IPS
function install-packages {
  local pids=""
  echo "++++++++++ Start installing packages ..."

  INSTANCE_EIPS="${MASTER_EIP},${NODE_EIPS}"
  IFS=',' read -ra instance_eip_arr <<< "${INSTANCE_EIPS}"
  for instance_eip in ${instance_eip_arr[*]}; do
    ${EXPECT_CMD} <<EOF &
set timeout -1
spawn ssh -t -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
  ${INSTANCE_USER}@${instance_eip} "\
sudo sh -c 'echo deb \[arch=amd64\] http://internal-get.caicloud.io/ubuntu docker main > /etc/apt/sources.list.d/docker.list' && \
sudo apt-get update && \
sudo apt-get install --allow-unauthenticated -y lxc-docker-$DOCKER_VERSION && \
sudo apt-get install bridge-utils"
expect {
  "*?assword*" {
    send -- "${KUBE_INSTANCE_PASSWORD}\r"
    exp_continue
  }
  eof {}
}
EOF
    pids="$pids $!"
  done

  echo "Wait for all instances to install packages ..."
  wait $pids
  echo "All instances finished installing packages ..."
}


# Configure master/nodes and start them concurrently.
#
# TODO: Add retry logic to install instances and provision instances.
#
# Assumed vars:
#   KUBE_INSTANCE_PASSWORD
#   MASTER_EIP
#   NODE_EIPS
function provision-instances {
  install-configurations

  local pids=""
  echo "++++++++++ Start provisioning master ..."
  # Call master-start.sh to start master.
  ${EXPECT_CMD} <<EOF &
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

  echo "++++++++++ Start provisioning nodes ..."
  IFS=',' read -ra node_eip_arr <<< "${NODE_EIPS}"
  for node_eip in "${node_eip_arr[@]}"; do
    # Call node-start.sh to start node. Note we must run expect in background;
    # otherwise, there will be a deadlock: node0-start.sh keeps retrying for etcd
    # connection (for docker-flannel configuration) because other nodes aren't
    # ready. If we run expect in foreground, we can't start other nodes; thus node0
    # will wait until timeout.
    ${EXPECT_CMD} <<EOF &
set timeout -1
spawn ssh -t -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet \
  ${INSTANCE_USER}@${node_eip} "sudo ./kube/node-start.sh"
expect {
  "*?assword*" {
    send -- "${KUBE_INSTANCE_PASSWORD}\r"
    exp_continue
  }
  eof {}
}
EOF
    pids="$pids $!"
  done

  echo "Wait for all instances to be provisioned ..."
  wait $pids
  echo "All instances have been provisioned ..."
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
#   ETCD_INITIAL_CLUSTER
#   SERVICE_CLUSTER_IP_RANGE
#   PRIVATE_SDN_INTERFACE
#   USER_CONFIG_FILE
#   DNS_SERVER_IP
#   DNS_DOMAIN
#   POD_INFRA_CONTAINER
function install-configurations {
  local pids=""

  echo "++++++++++ Start installing master configurations ..."
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
    echo "create-kube-apiserver-opts \"${SERVICE_CLUSTER_IP_RANGE}\" \"${ADMISSION_CONTROL}\""
    echo "create-kube-controller-manager-opts"
    echo "create-kube-scheduler-opts"
    echo "create-flanneld-opts ${PRIVATE_SDN_INTERFACE}"
    # Function 'create-private-interface-opts' creates network options used to
    # configure private sdn network interface.
    echo "create-private-interface-opts ${PRIVATE_SDN_INTERFACE} ${MASTER_INTERNAL_IP} ${INTERNAL_IP_MASK}"
    # The following lines organize file structure a little bit. To make it
    # pleasant when running the script multiple times, we ignore errors.
    echo "mv ~/kube/known-tokens.csv ~/kube/basic-auth.csv ~/kube/security 1>/dev/null 2>&1"
    echo "mv ~/kube/ca.crt ~/kube/master.crt ~/kube/master.key ~/kube/security 1>/dev/null 2>&1"
    echo "mv ~/kube/anchnet-config ~/kube/security/anchnet-config 1>/dev/null 2>&1"
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
      "${INSTANCE_USER}@${MASTER_EIP}":~/kube &
  pids="$pids $!"

  # Start installing nodes.
  IFS=',' read -ra node_iip_arr <<< "${NODE_INTERNAL_IPS}"
  IFS=',' read -ra node_eip_arr <<< "${NODE_EIPS}"
  IFS=',' read -ra node_instance_arr <<< "${NODE_INSTANCE_IDS}"

  # Randomly choose one daocloud accelerator.
  IFS=',' read -ra reg_mirror_arr <<< "${DAOCLOUD_ACCELERATOR}"
  reg_mirror=${reg_mirror_arr[$(( ${RANDOM} % 4 ))]}
  echo "Use daocloud registry mirror ${reg_mirror}"

  for (( i = 1; i < $(($NUM_MINIONS+1)); i++ )); do
    index=$(($i-1))
    echo "+++++++++ Start installing node-${index} configurations ..."
    local node_internal_ip=${node_iip_arr[${index}]}
    local node_eip=${node_eip_arr[${index}]}
    local node_instance_id=${node_instance_arr[${index}]}
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
      echo "create-etcd-opts kubernetes-node-${i} ${node_internal_ip} \"${ETCD_INITIAL_CLUSTER}\""
      echo "create-kubelet-opts ${node_instance_id} ${node_internal_ip} ${MASTER_INTERNAL_IP} ${DNS_SERVER_IP} ${DNS_DOMAIN} ${POD_INFRA_CONTAINER}"
      echo "create-kube-proxy-opts \"${MASTER_INTERNAL_IP}\""
      echo "create-flanneld-opts ${PRIVATE_SDN_INTERFACE}"
      # Create network options.
      echo "create-private-interface-opts ${PRIVATE_SDN_INTERFACE} ${node_internal_ip} ${INTERNAL_IP_MASK}"
      # Organize files a little bit.
      echo "mv ~/kube/kubelet-kubeconfig ~/kube/kube-proxy-kubeconfig ~/kube/security 1>/dev/null 2>&1"
      echo "mv ~/kube/anchnet-config ~/kube/security/anchnet-config 1>/dev/null 2>&1"
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
      echo "config-docker-net ${FLANNEL_NET} ${reg_mirror}"
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
        "${INSTANCE_USER}@${node_eip}":~/kube &
    pids="$pids $!"
  done

  echo -n "++++++++++ Waiting for all configurations to be installed ... "
  wait $pids
  echo "Done"
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


# A helper function that executes a command (which interacts with anchnet), and retries
# on failure. If the command can't succeed within given attempts, the script will exit
# directly.
#
# Input:
#   $1 command string to execute
#
# Output:
#   ANCHNET_RESPONSE response from anchnet. It is a global variable, so we can't use
#     then function concurrently.
function anchnet-exec-and-retry {
  local attempt=0
  while true; do
    ANCHNET_RESPONSE=$(eval $1)
    if [[ "$?" != "0" ]]; then
      if (( attempt > 20 )); then
        echo
        echo -e "${color_red}Unable to execute command [$1]${color_norm}" >&2
        exit 1
      fi
    else
      echo -e " ${color_green}Command [$1] ok${color_norm}" >&2
      break
    fi
    echo -e " ${color_yellow}Command [$1] not ok, will retry${color_norm}" >&2
    attempt=$(($attempt+1))
    sleep $(($attempt*2))
  done
}


# Wait until job finishes. If job doesn't finish within timeout, return error.
#
# Input:
#   $1 anchnet response, typically ANCHNET_RESPONSE.
#   $2 number of retry, default to 60
#   $3 retry interval, in second, default to 3
function anchnet-wait-job {
  echo -n "Wait until job finishes: ${1} ... "

  local job_id=$(echo ${1} | json_val '["job_id"]')
  ${ANCHNET_CMD} waitjob ${job_id} -c=${2-60} -i=${3-3}

  local exit_code=$?
  if [[ "$exit_code" == "0" ]]; then
    echo -e "${color_green}Done${color_norm}"
  else
    echo -e "${color_red}Failed${color_norm}"
  fi

  return $exit_code
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
    hack/caicloud-tools/k8s-replace.sh
    trap '${KUBE_ROOT}/hack/caicloud-tools/k8s-restore.sh' EXIT
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
    hack/caicloud-tools/k8s-replace.sh
    trap '${KUBE_ROOT}/hack/caicloud-tools/k8s-restore.sh' EXIT
    build/run.sh hack/build-go.sh
    cd -
  )
}


# -----------------------------------------------------------------------------
# Cluster specific test helpers used from hack/e2e-test.sh


# Perform preparations required to run e2e tests.
function prepare-e2e() {
  ensure-temp-dir

  cat > ${KUBE_TEMP}/e2e-config.sh <<EOF
export CLUSTER_ID="e2e-test"
export NUM_MINIONS=2
export MASTER_MEM=2048
export MASTER_CPU_CORES=2
export NODE_MEM=2048
export NODE_CPU_CORES=2
EOF
  export USER_CONFIG_FILE=${KUBE_TEMP}/e2e-config.sh
  export KUBE_UP_MODE="full"
  # Since we changed our config above, we reset anchnet env.
  setup-anchnet-env
  # As part of e2e preparation, we fix image path.
  ${KUBE_ROOT}/hack/caicloud-tools/k8s-replace.sh
  trap '${KUBE_ROOT}/hack/caicloud-tools/k8s-restore.sh' EXIT
}


# Execute prior to running tests to build a release if required for env.
#
# Assumed Vars:
#   KUBE_ROOT
function test-build-release {
  # In e2e test, we will run in full mode, i.e. build release and copy binaries,
  # so we do not need to build release here.  Note also, e2e test will test client
  # & server version match. Server binary uses dockerized build; however, developer
  # may use local kubectl (_output/local/bin/kubectl), so we do a local build here.
  echo "Anchnet e2e doesn't need pre-build release - release will be built during kube-up"
  (
    cd ${KUBE_ROOT}
    make clean
    hack/build-go.sh
    cd -
  )
}


# Execute prior to running tests to initialize required structure. This is
# called from hack/e2e.go only when running -up (it is ran after kube-up).
#
# Assumed vars:
#   Variables from config.sh
function test-setup {
  echo "Anchnet e2e doesn't need special test for setup (after kube-up)"
}


# Execute after running tests to perform any required clean-up. This is called
# from hack/e2e.go
function test-teardown {
  echo "No special handling for test-teardown"
}
