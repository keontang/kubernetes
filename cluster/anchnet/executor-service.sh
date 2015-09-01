#!/bin/bash

# Provides utility functions for talking back to cluster deployment executor.

# curl command constant.

# Sends out request based on the input url.
# Vars set:
# CURL_CMD
#
# Input:
# $1 The full url to access.
#
# Output:
# stdout: normal execution information.
# stderr: Record the url if fails.
function send-request-with-retry {
  if [[ ! -z $1 ]]; then
    local attempt=0
    local full_command="${CURL_CMD} -sL -w %{http_code} $1 -o /dev/null"
    while true; do
      echo "Attempt ${attempt}: ${full_command}"
      local resp_code=$(${full_command})
      echo "response_code: ${resp_code}"
      if [[ ${resp_code} == "200" ]]; then
        break
      fi
      attempt=$(($attempt+1))
      if (( attempt > 3 )); then
        echo "Failed to send the following request to executor \n: $1" 1>&2
        break
      fi
      sleep $(($attempt*2))
    done
  fi
}

# Note: for the rest functions, we assume the following variables are always set.
# Vars set:
# EXECUTOR_HOST_NAME
# EXECUTION_ID
#

# Report a list of ips back to the executor for recording.
# Input:
# $1 The list of comma deliminated ips.
# $2 M or N. M indicates the ips reported belong to the master,
#    and N indicates ips are for regular nodes.
#
function report-ips {
  if [[ ${REPORT_KUBE_STATUS-} == "Y" ]]; then
    if [[ ! -z "${EXECUTOR_HOST_NAME-}" && ! -z "${EXECUTION_ID-}" ]]; then
      send-request-with-retry "$EXECUTOR_HOST_NAME/report_ips?id=${EXECUTION_ID}&ips=$1&type=$2"
    else
      echo "EXECUTOR_HOST_NAME or EXECUTION_ID is not set up. report-ips failed."
    fi
  fi
}

# Report a list of instance ids back to the executor for recording.
#
# Input:
# $1 The list of comma deliminated instance ids.
# $2 M or N. M indicates the ips reported belong to the master,
#    and N indicates ips are for regular nodes.
#
function report-instance-ids {
  if [[ ${REPORT_KUBE_STATUS-} == "Y" ]]; then
    if [[ ! -z "${EXECUTOR_HOST_NAME-}" && ! -z "${EXECUTION_ID-}" ]]; then
      send-request-with-retry "$EXECUTOR_HOST_NAME/report_instance_ids?id=${EXECUTION_ID}&instances=$1&type=$2"
    else
      echo "EXECUTOR_HOST_NAME or EXECUTION_ID is not set up. report-instance-ids failed."
    fi
  fi
}

# Report a list of security group ids back to the executor for recording.
#
# Input:
# $1 The list of comma deliminated security group ids.
# $2 M or N. M indicates the ips reported belong to the master,
#    and N indicates ips are for regular nodes.
#
function report-security-group-ids {
  if [[ ${REPORT_KUBE_STATUS-} == "Y" ]]; then
    if [[ ! -z "${EXECUTOR_HOST_NAME-}" && ! -z "${EXECUTION_ID-}" ]]; then
      send-request-with-retry "$EXECUTOR_HOST_NAME/report_security_group_ids?id=${EXECUTION_ID}&security_groups=$1&type=$2"
    else
      echo "EXECUTOR_HOST_NAME or EXECUTION_ID is not set up. report-security-group-ids failed."
    fi
  fi
}

# Report a list of external ip ids back to the executor for recording.
#
# Input:
# $1 The list of comma deliminated eip ids.
#
function report-eip-ids {
  if [[ ${REPORT_KUBE_STATUS-} == "Y" ]]; then
    if [[ ! -z "${EXECUTOR_HOST_NAME-}" && ! -z "${EXECUTION_ID-}" ]]; then
      send-request-with-retry "$EXECUTOR_HOST_NAME/report_eip_ids?id=${EXECUTION_ID}&eips=$1"
    else
      echo "EXECUTOR_HOST_NAME or EXECUTION_ID is not set up. report-eip-ids failed."
    fi
  fi
}

function report-project-id {
  if [[ ${REPORT_KUBE_STATUS-} == "Y" ]]; then
    if [[ ! -z "${EXECUTOR_HOST_NAME-}" && ! -z "${USER_ID-}" ]]; then
      send-request-with-retry "$EXECUTOR_HOST_NAME/report_project_id?uid=${USER_ID}&projectid=$1"
    else
      echo "EXECUTOR_HOST_NAME or USER_ID is not set up. report-project-id failed."
    fi
  fi
}

# Report if kube-up succeeds or not.
#
# Input:
# $1 Y or N. Y for success and N for fail.
function kube-up-complete {
  if [[ ${REPORT_KUBE_STATUS-} == "Y" ]]; then
    if [[ ! -z "${EXECUTOR_HOST_NAME-}" && ! -z "${EXECUTION_ID-}" ]]; then
      send-request-with-retry "$EXECUTOR_HOST_NAME/complete?id=${EXECUTION_ID}&succ=$1"
    else
      echo "EXECUTOR_HOST_NAME or EXECUTION_ID is not set up. kube-up-compete failed."
    fi
  fi
}

# Make an log.
#
# Input:
# $1 a code of LogLevelType in execution_report_collection.go
# $2 a message to log
function report-log-entry {
  if [[ ${REPORT_KUBE_STATUS-} == "Y" ]]; then
    if [[ ! -z "${EXECUTOR_HOST_NAME-}" && ! -z "${EXECUTION_ID-}" ]]; then
      send-request-with-retry "$EXECUTOR_HOST_NAME/log?id=${EXECUTION_ID}&level=$1&msg=$2"
    else
      echo "EXECUTOR_HOST_NAME or EXECUTION_ID is not set up. report-log-entry failed."
    fi
  fi
}

# Commands for testing only
# CURL_CMD=curl
# REPORT_KUBE_STATUS="Y"
# EXECUTOR_HOST_NAME=localhost:8765
# EXECUTION_ID=55b599d0e4c2036358000003
# report-ips ip1,ip2 M
# report-ips ip1,ip2 N
# report-instance-ids master-instance,node-instance1,node-instance2 N
# report-security-group-ids sg1,sg2 M
# report-eip-ids eip1,eip2
# kube-up-complete Y
# kube-up-complete N
# report-log-entry 1 msg
