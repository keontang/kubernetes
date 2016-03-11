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

KUBE_ROOT="$(dirname "${BASH_SOURCE}")/../.."

# Get cluster configuration parameters from config-default, as well as all
# other utilities. Note KUBE_DISTRO will be available after sourcing file
# config-default.sh.
source "${KUBE_ROOT}/cluster/caicloud-baremetal/config-default.sh"
source "${KUBE_ROOT}/cluster/caicloud/common.sh"
source "${KUBE_ROOT}/cluster/caicloud/executor-service.sh"
source "${KUBE_ROOT}/cluster/caicloud/${KUBE_DISTRO}/helper.sh"


# -----------------------------------------------------------------------------
# Cluster specific library utility functions.
# -----------------------------------------------------------------------------
# Verify cluster prerequisites.
function verify-prereqs {
  if [[ "$(which curl)" == "" ]]; then
    log "Can't find curl in PATH, please fix and retry."
    exit 1
  fi
  if [[ "$(which expect)" == "" ]]; then
    log "Can't find expect binary in PATH, please fix and retry."
    exit 1
  fi
}

# Instantiate a kubernetes cluster
function kube-up {
  # Print all environment and local variables at this point.
  log "+++++ Running kube-up with variables ..."
  KUBE_UP=Y && (set -o posix; set)

  # Make sure we have:
  #  1. a staging area
  #  2. a public/private key pair used to provision instances.
  ensure-temp-dir
  ensure-ssh-agent

  # setup-instances is a common operations aross all cloudproviders, including
  # baremetal, see caicloud/common.sh for a list of setups.
  setup-instances
  # setup-baremetal-instances is baremetal specific setups for all instances.
  setup-baremetal-instances

  # Create certificates and credentials to secure cluster communication.
  create-certs-and-credentials

  # Setup instances to facilitate provision, see caicloud/common.sh.
  setup-instances

  # Concurrently install all binaries and packages for instances.
  local pids=""
  fetch-tarball-in-master && install-binaries-from-master & pids="$pids $!"
  install-packages & pids="$pids $!"
  wait ${pids}

  # Prepare master environment.
  send-master-files
  send-node-files

  # Now start kubernetes.
  start-kubernetes

  # Create config file, i.e. ~/.kube/config.
  source "${KUBE_ROOT}/cluster/common.sh"
  # create-kubeconfig assumes master ip is in the variable KUBE_MASTER_IP.
  # Also, in bare metal environment, we are deploying on master instance,
  # so we make sure it can find kubectl binary.
  if [[ ${USE_SELF_SIGNED_CERT} == "true" ]]; then
    KUBE_MASTER_IP="${MASTER_IIP}"
  else
    KUBE_MASTER_IP="${MASTER_DOMAIN_NAME}"
  fi

  find-kubectl-binary
  create-kubeconfig
}

# Validate a kubernetes cluster
function validate-cluster {
  # by default call the generic validate-cluster.sh script, customizable by
  # any cluster provider if this does not fit.
  "${KUBE_ROOT}/cluster/validate-cluster.sh"

  echo "... calling deploy-addons" >&2
  deploy-addons "${MASTER_SSH_INFO}"
}

# Delete a kubernetes cluster
function kube-down {
  # Print all environment and local variables at this point.
  KUBE_UP=N && (set -o posix; set)

  # Make sure we have:
  #  1. a staging area
  #  2. a public/private key pair used to provision instances.
  ensure-temp-dir
  ensure-ssh-agent
  # Not actually used in kube-down, but call it to avoid the following
  # non-fatal errors:
  #  /home/vagrant/kube/kubelet-kubeconfig: No such file or directory
  #  /home/vagrant/kube/kube-proxy-kubeconfig: No such file or directory
  create-certs-and-credentials

  send-master-files
  send-node-files

  cleanup-kubernetes
}

# Must ensure that the following ENV vars are set
function detect-master {
  echo "KUBE_MASTER_IP: $KUBE_MASTER_IP" 1>&2
  echo "KUBE_MASTER: $KUBE_MASTER" 1>&2
}

# Get minion names if they are not static.
function detect-minion-names {
  echo "MINION_NAMES: [${MINION_NAMES[*]}]" 1>&2
}

# Get minion IP addresses and store in KUBE_MINION_IP_ADDRESSES[]
function detect-minions {
  echo "KUBE_MINION_IP_ADDRESSES: [${KUBE_MINION_IP_ADDRESSES[*]}]" 1>&2
}

# Setup baremetal instances. Right now, the only setup is to add node hostname entry
# into master, so that master can reach nodes via their hostname.
function setup-baremetal-instances {
  IFS=',' read -ra instance_ssh_info <<< "${INSTANCE_SSH_EXTERNAL}"
  (
    echo "#!/bin/bash"
    grep -v "^#" "${KUBE_ROOT}/cluster/caicloud/${KUBE_DISTRO}/helper.sh"
    for (( i = 0; i < ${#instance_ssh_info[*]}; i++ )); do
      INSTANCE_HOSTNAME=`ssh-to-instance "${instance_ssh_info[$i]}" "hostname"`
      IFS=':@' read -ra ssh_info <<< "${instance_ssh_info[$i]}"
      echo "add-hosts-entry ${INSTANCE_HOSTNAME} ${ssh_info[2]}"
    done
    echo ""
  ) > "${KUBE_TEMP}/master-host-setup.sh"
  chmod a+x "${KUBE_TEMP}/master-host-setup.sh"

  scp-then-execute-expect "${MASTER_SSH_EXTERNAL}" "${KUBE_TEMP}/master-host-setup.sh" "~" "\
mkdir -p ~/kube && sudo mv ~/master-host-setup.sh ~/kube && \
sudo ./kube/master-host-setup.sh || \
echo 'Command failed setting up master'"
}
