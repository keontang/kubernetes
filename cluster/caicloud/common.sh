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
# The script contains common functions used to provision caicloud kubernetes.
# Assumed vars in some of the functions should be available after sourcing
# file: cluster/${KUBERNETES_PROVIDER}/config-default.sh.
#

# -----------------------------------------------------------------------------
# Cluster related common operations.
# -----------------------------------------------------------------------------

# Deploy caicloud enabled addons.
#
# At this point, addon secrets should be created (in create-certs-and-credentials).
# Note we have to create the secrets beforehand, so that when provisioning master,
# it knows all the tokens (including addons). All other addons related setup will
# need to be performed here.
#
# Addon yaml files are copied from cluster/addons, with slight modifications to
# fit into caicloud environment.
#
# TODO: Make deploy addons robust.
#
# Input:
#   $1 Master ssh info, e.g. root:password@43.254.54.58
#
# Assumed vars:
#   KUBE_TEMP
#   KUBE_ROOT
#   DNS_REPLICAS
#   DNS_SERVER_IP
#   ELASTICSEARCH_REPLICAS
#   KIBANA_REPLICAS
#   KUBE_UI_REPLICAS
function deploy-addons {
  log "+++++ Deploy caicloud addons"
  # Replace placeholder with our configuration for dns rc/svc.
  local -r skydns_rc_file="${KUBE_ROOT}/cluster/caicloud/addons/dns/skydns-rc.yaml.in"
  local -r skydns_svc_file="${KUBE_ROOT}/cluster/caicloud/addons/dns/skydns-svc.yaml.in"
  sed -e "s/{{ pillar\['dns_replicas'\] }}/${DNS_REPLICAS}/g;s/{{ pillar\['dns_domain'\] }}/${DNS_DOMAIN}/g" ${skydns_rc_file} > ${KUBE_TEMP}/skydns-rc.yaml
  sed -e "s/{{ pillar\['dns_server'\] }}/${DNS_SERVER_IP}/g" ${skydns_svc_file} > ${KUBE_TEMP}/skydns-svc.yaml

  # Replace placeholder with our configuration for elasticsearch rc.
  local -r elasticsearch_rc_file="${KUBE_ROOT}/cluster/caicloud/addons/logging/elasticsearch-rc.yaml.in"
  sed -e "s/{{ pillar\['elasticsearch_replicas'\] }}/${ELASTICSEARCH_REPLICAS}/g" ${elasticsearch_rc_file} > ${KUBE_TEMP}/elasticsearch-rc.yaml

  # Replace placeholder with our configuration for kibana rc.
  local -r kibana_rc_file="${KUBE_ROOT}/cluster/caicloud/addons/logging/kibana-rc.yaml.in"
  sed -e "s/{{ pillar\['kibana_replicas'\] }}/${KIBANA_REPLICAS}/g" ${kibana_rc_file} > ${KUBE_TEMP}/kibana-rc.yaml

  # Replace placeholder with our configuration for kube-ui rc.
  local -r kube_ui_rc_file="${KUBE_ROOT}/cluster/caicloud/addons/kube-ui/kube-ui-rc.yaml.in"
  sed -e "s/{{ pillar\['kube-ui_replicas'\] }}/${KUBE_UI_REPLICAS}/g" ${kube_ui_rc_file} > ${KUBE_TEMP}/kube-ui-rc.yaml

  # Copy addon configurationss and startup script to master instance under ~/kube.
  rm -rf ${KUBE_TEMP}/addons && mkdir -p ${KUBE_TEMP}/addons/dns ${KUBE_TEMP}/addons/logging ${KUBE_TEMP}/addons/kube-ui
  cp ${KUBE_TEMP}/skydns-rc.yaml ${KUBE_TEMP}/skydns-svc.yaml ${KUBE_TEMP}/addons/dns
  cp ${KUBE_TEMP}/elasticsearch-rc.yaml ${KUBE_ROOT}/cluster/caicloud/addons/logging/elasticsearch-svc.yaml \
     ${KUBE_TEMP}/kibana-rc.yaml ${KUBE_ROOT}/cluster/caicloud/addons/logging/kibana-svc.yaml ${KUBE_TEMP}/addons/logging
  cp ${KUBE_TEMP}/kube-ui-rc.yaml ${KUBE_ROOT}/cluster/caicloud/addons/kube-ui/kube-ui-svc.yaml ${KUBE_TEMP}/addons/kube-ui
  scp-to-instance \
    "${1}" \
    "${KUBE_TEMP}/addons ${KUBE_ROOT}/cluster/caicloud/addons/namespace.yaml ${KUBE_ROOT}/cluster/caicloud/addons/addons-start.sh" \
    "~/kube"

  # Call 'addons-start.sh' to start addons.
  ssh-to-instance \
    "${1}" \
    "sudo SYSTEM_NAMESPACE=${SYSTEM_NAMESPACE} ENABLE_CLUSTER_DNS=${ENABLE_CLUSTER_DNS} ENABLE_CLUSTER_LOGGING=${ENABLE_CLUSTER_LOGGING} ENABLE_CLUSTER_UI=${ENABLE_CLUSTER_UI} ./kube/addons-start.sh"
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
# Input:
#  $1 Master internal IP
#  $2 Master external IP, leave empty if there is no external IP
#
# Assumed vars
#   KUBE_ROOT
#   KUBE_TEMP
#   MASTER_NAME
#   MASTER_SECURE_PORT
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
  log "+++++ Create certificates, credentials and secrets"

  # 'octects' will be an arrary of segregated IP, e.g. 192.168.3.0/24 => 192 168 3 0
  # 'service_ip' is the first IP address in SERVICE_CLUSTER_IP_RANGE; it is the service
  #  created to represent kubernetes api itself, i.e. kubectl get service:
  #    NAME         LABELS                                    SELECTOR   IP(S)         PORT(S)
  #    kubernetes   component=apiserver,provider=kubernetes   <none>     192.168.3.1   443/TCP
  # 'sans' are all the possible names that the ca certifcate certifies.
  local octects=($(echo "${SERVICE_CLUSTER_IP_RANGE}" | sed -e 's|/.*||' -e 's/\./ /g'))
  ((octects[3]+=1))
  local service_ip=$(echo "${octects[*]}" | sed 's/ /./g')
  local sans="IP:${1},IP:${service_ip}"
  # Add external IP if provided.
  if [[ "${2:-}" != "" ]]; then
    sans="${sans},IP:${2}"
    master_ip="${2}"
  else
    master_ip="${1}"
  fi
  sans="${sans},DNS:kubernetes,DNS:kubernetes.default,DNS:kubernetes.default.svc"
  sans="${sans},DNS:kubernetes.default.svc.${DNS_DOMAIN},DNS:${MASTER_NAME},DNS:master"

  # Create cluster certificates.
  (
    cp "${KUBE_ROOT}/cluster/caicloud/easy-rsa.tar.gz" "${KUBE_TEMP}"
    cd "${KUBE_TEMP}"
    tar xzf easy-rsa.tar.gz > /dev/null 2>&1
    cd easy-rsa-master/easyrsa3
    ./easyrsa init-pki > /dev/null 2>&1
    ./easyrsa --batch "--req-cn=${master_ip}@$(date +%s)" build-ca nopass > /dev/null 2>&1
    ./easyrsa --subject-alt-name="${sans}" build-server-full master nopass > /dev/null 2>&1
    ./easyrsa build-client-full kubelet nopass > /dev/null 2>&1
    ./easyrsa build-client-full kubectl nopass > /dev/null 2>&1
  ) || {
    log "${color_red}=== Failed to generate certificates: Aborting ===${color_norm}"
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
    create-kubeconfig-secret "${token}" "${account}" "https://${master_ip}:${MASTER_SECURE_PORT}" "${KUBE_TEMP}/${account}-secret.yaml"
    echo "${token},${account},${account}" >> "${KUBE_TEMP}/known-tokens.csv"
  done
}

# Create a kubeconfig file used for addons to contact apiserver. Note this is not
# used to create kubeconfig for kubelet and kube-proxy, since they have slightly
# different contents. This is only used in function "create-certs-and-credentials".
#
# Input:
#   $1 The base64 encoded token
#   $2 Username, e.g. system:dns
#   $3 Server to connect to, e.g. master_ip:port
#   $4 File to write the secret.
function create-kubeconfig-secret {
  local -r token=${1}
  local -r username=${2}
  local -r server=${3}
  local -r file=${4}
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
  cat > ${file} <<EOF
apiVersion: v1
data:
  kubeconfig: ${kubeconfig_base64}
kind: Secret
metadata:
  name: token-${safe_username}
type: Opaque
EOF
}

# Start a kubernetes cluster. The function assumes that master and nodes have
# already been setup correctly.
#
# Input:
#   $1 Master ssh info, e.g. root:password@43.254.54.58
#   $2 Node ssh info, e.g. "root:password@43.254.54.59,root:password@43.254.54.60"
function start-kubernetes {
  local pids=""
  IFS=',' read -ra node_ssh_info <<< "${2}"
  ssh-to-instance "${1}" "sudo ./kube/master-start.sh" & pids="${pids} $!"
  for ssh_info in "${node_ssh_info[@]}"; do
    ssh-to-instance "${ssh_info}" "sudo ./kube/node-start.sh" & pids="${pids} $!"
  done
  wait ${pids}
}

# Create a comma separated string of node internal ips based on the cluster config
# NODE_IIP_RANGE and NUM_MINIONS. E.g. if NODE_IIP_RANGE is 10.244.1.0/16 and
# NUM_MINIONS is 2, then output is: "10.244.1.0,10.244.1.1".
#
# Assumed vars:
#   NODE_IIP_RANGE
#   NUM_MINIONS
#
# Vars set:
#   NODE_IIPS
function create-node-internal-ips-variable {
  # Transform NODE_IIP_RANGE into different info, e.g. 10.244.1.0/16 =>
  #   cidr = 16
  #   ip_octects = 10 244 1 0
  #   mask_octects = 255 255 0 0
  cidr=($(echo "$NODE_IIP_RANGE" | sed -e 's|.*/||'))
  ip_octects=($(echo "$NODE_IIP_RANGE" | sed -e 's|/.*||' -e 's/\./ /g'))
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
    log "Number of nodes is larger than allowed node internal IP address"
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
    if [[ -z "${NODE_IIPS-}" ]]; then
      NODE_IIPS="${ip}"
    else
      NODE_IIPS="${NODE_IIPS},${ip}"
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

# Convert cidr to netmask, e.g. 16 -> 255.255.0.0. This is only called from
# function "create-node-internal-ips-variable".
#
# Input:
#   $1 cidr
function cdr2mask {
  # Number of args to shift, 255..255, first non-255 byte, zeroes
  set -- $(( 5 - ($1 / 8) )) 255 255 255 255 $(( (255 << (8 - ($1 % 8))) & 255 )) 0 0 0
  [ $1 -gt 1 ] && shift $1 || shift
  echo ${1-0}.${2-0}.${3-0}.${4-0}
}

# Fetch tarball from CAICLOUD_TARBALL_URL and save it to ${KUBE_TEMP}; then
# extract it to ${KUBE_TEMP}. The tarball is used to bring up caicloud kubernetes
# cluster.
#
# Assumed vars:
#   KUBE_TEMP
#   CAICLOUD_KUBE_PKG
#   CAICLOUD_TARBALL_URL
function fetch-and-extract-tarball {
  log "+++++ Fetch and extract caicloud kubernetes tarball"
  cd ${KUBE_TEMP}
  if [[ ! -f /tmp/${CAICLOUD_KUBE_PKG} ]]; then
    wget ${CAICLOUD_TARBALL_URL}
    cp ${CAICLOUD_KUBE_PKG} /tmp
    mv ${CAICLOUD_KUBE_PKG} caicloud-kube.tar.gz
  else
    cp /tmp/${CAICLOUD_KUBE_PKG} ${KUBE_TEMP}/caicloud-kube.tar.gz
  fi
  tar xvzf caicloud-kube.tar.gz
  cd - > /dev/null
}


# -----------------------------------------------------------------------------
# Generic common operations.
# -----------------------------------------------------------------------------

# Create a temp dir that'll be deleted at the end of bash session.
#
# Vars set:
#   KUBE_TEMP
function ensure-temp-dir {
  if [[ -z ${KUBE_TEMP-} ]]; then
    KUBE_TEMP=$(mktemp -d -t kubernetes.XXXXXX)
    trap 'rm -rf "${KUBE_TEMP}"' EXIT
  fi
}

# Timestamped log, e.g. log "cluster created".
#
# Input:
#   $1 Log string.
function log {
  echo -e "[`TZ=Asia/Shanghai date`] ${1}"
}

# Timestamped log without newline, e.g. log "cluster created".
#
# Input:
#   $1 Log string.
function log-oneline {
  echo -en "[`TZ=Asia/Shanghai date`] ${1}"
}

# Create ~/.ssh/id_rsa.pub if it doesn't exist.
function ensure-pub-key {
  if [[ ! -f ${HOME}/.ssh/id_rsa.pub ]]; then
    log "+++++++++ Create public/private key pair in ~/.ssh/id_rsa"
    ssh-keygen -f ~/.ssh/id_rsa -t rsa -N ''
  fi
}

# Ensure that we have a password created for validating to the master. Note
# the username/password here is used to login to kubernetes cluster, not for
# ssh into machines.
#
# Vars set (if not set already):
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

# Make sure log directory exists.
#
# Assumed vars
#   KUBE_INSTANCE_LOGDIR
function ensure-log-dir {
  if [[ ! -z ${KUBE_INSTANCE_LOGDIR-} ]]; then
    mkdir -p ${KUBE_INSTANCE_LOGDIR}
  fi
}

# ssh to given node and execute command, e.g.
#   ssh-to-instance "root:password@43.254.54.58" "touch abc && mkdir def"
#
# Input:
#   $1 ssh info, e.g. root:password@43.254.54.58
#   $2 Command string
function ssh-to-instance {
  ssh_opts="-oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet"
  IFS=':@' read -ra ssh_info <<< "${1}"
  expect <<EOF
set timeout -1
spawn ssh -t ${ssh_opts} ${ssh_info[0]}@${ssh_info[2]} ${2}
expect {
  "*?assword*" {
    send -- "${ssh_info[1]}\r"
    exp_continue
  }
  eof {}
}
EOF
}

# scp files to given instance, e.g.
#  scp-to-instance "root:password@43.254.54.58" "file1 file2" "~/destdir"
#
# Input:
#   $1 ssh info, e.g. root:password@43.254.54.58
#   $2 files to copy, separate with space
#   $3 destination directory on remote machine
function scp-to-instance {
  ssh_opts="-oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet"
  IFS=':@' read -ra ssh_info <<< "${1}"
  expect <<EOF
set timeout -1
spawn scp -r ${ssh_opts} ${2} ${ssh_info[0]}@${ssh_info[2]}:${3}
expect {
  "*?assword:" {
    send -- "${ssh_info[1]}\r"
    exp_continue
  }
  eof {}
}
EOF
}

# Randomly choose one daocloud accelerator.
#
# TODO: Use our own registry.
#
# Assumed vars:
#   DAOCLOUD_ACCELERATORS
#
# Vars set:
#   REG_MIRROR
function find-registry-mirror {
  IFS=',' read -ra reg_mirror_arr <<< "${DAOCLOUD_ACCELERATORS}"
  REG_MIRROR=${reg_mirror_arr[$(( ${RANDOM} % ${#reg_mirror_arr[*]} ))]}
  log "Use daocloud registry mirror ${REG_MIRROR}"
}

# Build all binaries using docker. Note there are some restrictions we need
# to fix if the provision host is running in mainland China; it is fixed in
# k8s-replace.sh.
function caicloud-build-release {
  if [[ `uname` == "Darwin" ]]; then
    boot2docker start
  fi
  cd ${KUBE_ROOT}
  hack/caicloud/k8s-replace.sh
  trap '${KUBE_ROOT}/hack/caicloud/k8s-restore.sh' EXIT
  build/release.sh
  cd -
}

# Like build release, but only build server binary (linux amd64).
function caicloud-build-server {
  if [[ `uname` == "Darwin" ]]; then
    boot2docker start
  fi
  cd ${KUBE_ROOT}
  hack/caicloud/k8s-replace.sh
  trap '${KUBE_ROOT}/hack/caicloud/k8s-restore.sh' EXIT
  build/run.sh hack/build-go.sh
  cd -
}

# Build release tarball.
#
# Assumed vars:
#   FINAL_VERSION
function caicloud-build-tarball {
  cd ${KUBE_ROOT}
  ./hack/caicloud/build-tarball.sh ${FINAL_VERSION}
  cd -
}

# Build local binaries.
function caicloud-build-local {
  cd ${KUBE_ROOT}
  hack/build-go.sh
  cd -
}

# Clean up repository.
function make-clean {
  cd ${KUBE_ROOT}
  make clean
  cd -
}

# A helper function that executes a command (or shell function), and retries on
# failure. If the command can't succeed within given attempts, the script will
# exit directly.
#
# Input:
#   $1 command string to execute
#   $2 number of retries, default to 20
#   $3 report failure; if true, report failure to caicloud cluster manager.
function command-exec-and-retry {
  local attempt=0
  local count=${2-20}
  local report=${3-"true"}
  while true; do
    eval $1
    if [[ "$?" != "0" ]]; then
      if (( attempt >= ${count} )); then
        echo
        log "${color_red}Unable to execute command [$1]: Timeout${color_norm}" >&2
        if [[ "${report}" = "true" ]]; then
           kube-up-complete N
        fi
        exit 1
      fi
    else
      log "${color_green}Command [$1] ok${color_norm}" >&2
      break
    fi
    log "${color_yellow}Command [$1] not ok, will retry${color_norm}" >&2
    attempt=$(($attempt+1))
    sleep $(($attempt*2))
  done
}
