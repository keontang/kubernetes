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
# file: cluster/${KUBERNETES_PROVIDER}/config-default.sh, i.e.
#   DNS_DOMAIN
#   MASTER_NAME
#   MASTER_SECURE_PORT
#   SERVICE_CLUSTER_IP_RANGE
#

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
  echo "[`TZ=Asia/Shanghai date`] $1"
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
#  ssh-to-instance "root@43.254.54.58" "touch abc && mkdir def" "password"
#
# Input:
#   $1 username and node address, e.g. root@43.254.54.58
#   $2 command string
#   $3 optional passward if needed
function ssh-to-instance {
  ssh_opts="-oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet"
  expect <<EOF
set timeout -1
spawn ssh -t ${ssh_opts} $1 $2
expect {
  "*?assword*" {
    send -- "${3}\r"
    exp_continue
  }
  eof {}
}
EOF
}

# scp files to given instance, e.g.
#  scp-to-instance "file1 file2" "root@43.254.54.58" "~/destdir" "password"
#
# Input:
#   $1 files to copy, separate with space
#   $2 username and node address, e.g. root@43.254.54.58
#   $3 destination directory on remote machine
#   $4 optional passward if needed
function scp-to-instance {
  ssh_opts="-oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=quiet"
  expect <<EOF
set timeout -1
spawn scp -r ${ssh_opts} $1 $2:$3
expect {
  "*?assword:" {
    send -- "${4}\r"
    exp_continue
  }
  eof {}
}
EOF
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

# Start a kubernetes cluster.
#
# Input:
#   $1 Master IP
#   $2 Node IPs
#   $3 optional passward if needed
function start-kubernetes {
  local pids=""
  ssh-to-instance "${INSTANCE_USER}@${1}" "sudo ./kube/master-start.sh" "$3" & pids="${pids} $!"
  for (( i = 0; i < $(($NUM_MINIONS)); i++ )); do
    local node_ip=${NODE_IPS_ARR[${i}]}
    ssh-to-instance "${INSTANCE_USER}@${node_ip}" "sudo ./kube/node-start.sh" "${3}" & pids="${pids} $!"
  done
  wait ${pids}
}

# Deploy caicloud enabled addons.
#
# At this point, addon secrets should be created (in create-certs-and-credentials).
# Note we have to create the secrets beforehand, so that when provisioning master,
# it knows all the tokens (including addons). All other addons related setup will
# need to be performed here.
#
# Addon yaml files are copied from cluster/addons, with slight modifications to
# fit into caicloud environment.
function deploy-addons {
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
  scp-to-instance "${KUBE_TEMP}/addons ${KUBE_ROOT}/cluster/caicloud/addons/namespace.yaml ${KUBE_ROOT}/cluster/caicloud/addons/addons-start.sh" "${1}" "~/kube" "${2:-}"

  # Call 'addons-start.sh' to start addons.
  ssh-to-instance "${1}" "sudo SYSTEM_NAMESPACE=${SYSTEM_NAMESPACE} ENABLE_CLUSTER_DNS=${ENABLE_CLUSTER_DNS} ENABLE_CLUSTER_LOGGING=${ENABLE_CLUSTER_LOGGING} ENABLE_CLUSTER_UI=${ENABLE_CLUSTER_UI} ./kube/addons-start.sh" "${2:-}"
}

# Fetch tarball from CAICLOUD_TARBALL_URL and extract it to ${KUBE_TEMP}.
#
# Assumed vars:
#   CAICLOUD_KUBE_PKG
#   CAICLOUD_TARBALL_URL
#   KUBE_TEMP
function fetch-and-extract-tarball {
  cd ${KUBE_TEMP}
  if [[ ! -f /tmp/${CAICLOUD_KUBE_PKG} ]]; then
    wget ${CAICLOUD_TARBALL_URL}
    cp ${CAICLOUD_KUBE_PKG} /tmp
    mv ${CAICLOUD_KUBE_PKG} caicloud-kube.tar.gz
  else
    cp /tmp/caicloud-kube.tar.gz ${KUBE_TEMP}
  fi
  tar xvzf caicloud-kube.tar.gz
  cd - > /dev/null
}

# Randomly choose one daocloud accelerator.
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
