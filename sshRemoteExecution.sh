#!/bin/bash
# @Author: nguyendt456
#################################################
# Execute command or features on remote VM by ssh
# Usage: chmod +x sshRemoteExecution.sh
#        ./sshRemoteExecution.sh --help
#################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'
FAIL_LOG="${RED}FAIL${NC} "
SUCCESS_LOG="${GREEN}SUCCESS${NC}"
INFO_LOG="[${CYAN}INFO${NC}] "
while [[ $# -gt 0 ]]; do
case $1 in
  -h | --hostname)
    if [[ -z "$2" ]]; then
        echo -e "${FAIL_LOG}    $1 takes exactly 1 argument! (expected SSH host)"
      exit 1
    fi
    HOST_NAME=$2
    shift
    shift
    ;;
  -u | --user)
    if [[ -z "$2" ]]; then
      echo -e "${FAIL_LOG}    $1 takes exactly 1 argument (expected SSH user)"
      exit 1
    fi
    _USER=$2
    shift
    shift
    ;;
  --help)
    echo -e "    -h | --hostname       SSH hostname. Hostname could be IP"
    echo -e "    -u | --user           SSH user. User of the remote server"
    echo -e "    -k | --key-exchange   Set up key exchange for public key authentication (without password)"
    echo -e "         --help           Usage Guide"
    exit 0
    ;;
  *)
    break
    ;;
esac
done
if [[ -n "$1" ]]; then
  echo -e "$1" | grep "@" > /dev/null
  if [[ $? -ne 0 ]]; then
    echo -e "${FAIL_LOG}   Invalid arguments !"
    exit 1
  fi
  IFS="@" read -r -a ssh_splitted <<< $1
  if [[ $? -ne 0 ]]; then
   echo -e "${FAIL_LOG}  Wrong format SSH !"
   exit 1
  fi
  _USER=${ssh_splitted[0]}
  HOST_NAME=${ssh_splitted[1]}
fi
if [[ -n "$1" && -z "$2" ]]; then
  echo -e "\n############# ${CYAN}SSH key exchange setting up${NC} #############"
  if [[ -z "${_USER}" || -z "${HOST_NAME}" ]]; then
    echo -e "${FAIL_LOG}   SSH User and SSH Hostname is required. Usually in this format: User@Hostname. Hostname could be IP"
    exit 1
  fi
  echo -e "\n    ${GREEN}*${NC} Detected SSH user: ${_USER}"
  echo -e "    ${GREEN}*${NC} Detected SSH hostname: ${HOST_NAME}\n"
  ssh ${_USER}@${HOST_NAME} "\
  cat ~/.ssh/authorized_keys &> /dev/null;
  if [[ \$? -eq 0 ]]; then
    cat ~/.ssh/authorized_keys | grep \"${USER}@${HOSTNAME}\" > /dev/null;
    if [[ \$? -ne 0 ]]; then
      cat - >> ~/.ssh/authorized_keys;
    else
      echo -e \"${INFO_LOG}    Detected user public key already exists\"
      echo -e \"${SUCCESS_LOG}    Finish setup authorized key. Now you can SSH to this host without password\"
    fi
  else
    echo -e \"${INFO_LOG}    authorized_keys file is not existed !\"
    touch ~/.ssh/authorized_keys && cat - >> ~/.ssh/authorized_keys
    echo -e \"${SUCCESS_LOG}    Finish setup authorized key. Now you can SSH this host password\"
  fi;\
  " < ~/.ssh/id_rsa.pub
  exit 0
fi
echo -e "${INFO_LOG}    Execute command to remote machine by SSH"
ssh -t ${_USER}@${HOST_NAME} "${2}"
