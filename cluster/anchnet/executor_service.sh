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
function report_ips {
  if [[ ! -z "${EXECUTOR_HOST_NAME-}" && ! -z "${EXECUTION_ID-}" ]]; then
    send-request-with-retry "$EXECUTOR_HOST_NAME/report_ips?id=${EXECUTION_ID}&ips=$1&type=$2"
  fi
}

# Report a list of instance ids back to the executor for recording.
#
# Input:
# $1 The list of comma deliminated instance ids.
#
function report_instance_ids {
  if [[ ! -z "${EXECUTOR_HOST_NAME-}" && ! -z "${EXECUTION_ID-}" ]]; then
    send-request-with-retry "$EXECUTOR_HOST_NAME/report_instance_ids?id=${EXECUTION_ID}&instances=$1"
  fi
}

# Report a list of security group ids back to the executor for recording.
#
# Input:
# $1 The list of comma deliminated security group ids.
#
function report_security_group_ids {
  if [[ ! -z "${EXECUTOR_HOST_NAME-}" && ! -z "${EXECUTION_ID-}" ]]; then
    send-request-with-retry "$EXECUTOR_HOST_NAME/report_security_group_ids?id=${EXECUTION_ID}&security_groups=$1"
  fi
}

# Report a list of external ip ids back to the executor for recording.
#
# Input:
# $1 The list of comma deliminated eip ids.
#
function report_eip_ids {
  if [[ ! -z "${EXECUTOR_HOST_NAME-}" && ! -z "${EXECUTION_ID-}" ]]; then
    send-request-with-retry "$EXECUTOR_HOST_NAME/report_eip_ids?id=${EXECUTION_ID}&eips=$1"
  fi
}

# Report if kube-up succeeds or not.
#
# Input:
# $1 "Y|N" indicating if the result of kube-up.
#
function complete {
  if [[ ! -z "${EXECUTOR_HOST_NAME-}" && ! -z "${EXECUTION_ID-}" ]]; then
    send-request-with-retry "$EXECUTOR_HOST_NAME/complete?id=${EXECUTION_ID}&succ=$1"
  fi
}

# Make an info log.
#
# Input:
# $1 a code of InfoLogType in execution_report_collection.go
#
function log_info {
  if [[ ! -z "${EXECUTOR_HOST_NAME-}" && ! -z "${EXECUTION_ID-}" ]]; then
    send-request-with-retry "$EXECUTOR_HOST_NAME/info?id=${EXECUTION_ID}&info_code=$1"
  fi
}

# Make an error log.
#
# Input:
# $1 a code of ErrorLogType in execution_report_collection.go
#
function log_error {
  if [[ ! -z "${EXECUTOR_HOST_NAME-}" && ! -z "${EXECUTION_ID-}" ]]; then
    send-request-with-retry "$EXECUTOR_HOST_NAME/error?id=${EXECUTION_ID}&error_code=$1"
  fi
}

# Commands for testing only
#CURL_CMD=curl
#EXECUTOR_HOST_NAME=localhost:8765
#EXECUTION_ID=55b599d0e4c2036358000003
#report_ips ip1,ip2 M
#report_ips ip1,ip2 N
#report_instance_ids master-instance,node-instance1,node-instance2
#report_security_group_ids sg1,sg2
#report_eip_ids eip1,eip2
#complete Y
#complete N
#log_info 1
#log_error 1