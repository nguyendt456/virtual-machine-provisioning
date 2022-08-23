#!/bin/bash
# @Author: nguyendt456
######################
# Service for automate send api request to update public IP if changed
# Specify for Google domain api
# Usage :

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'
FAIL_LOG="${RED}FAIL${NC} "
SUCCESS_LOG="${GREEN}SUCCESS${NC}"
INFO_LOG="[${CYAN}INFO${NC}] "

validateIPaddress () {
  IFS='.' read -r -a IP_part <<< "$1"
  if [[  -z "${IP_part[0]}"   ||  -z "${IP_part[1]}"   || \
         -z "${IP_part[2]}"   ||  -z "${IP_part[3]}"   && -z "${IP_part[4]}" || \
        ${IP_part[0]} -gt 255 || ${IP_part[1]} -gt 255 || \
        ${IP_part[2]} -gt 255 || ${IP_part[3]} -gt 255 ]]; then
    echo -e "${FAIL_LOG}    Invalid IP address version 4. Please check the format again"
    exit 1
  fi
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -m  | --mode)
      if [[ "$2" == "service" ]]; then
        MODE="service"
      else
        echo -e "${FAIL_LOG}    $1 invalid mode (valid: initialize)"
        exit 1
      fi
      shift
      shift
      ;;
    -u | --username)
      if [[ -z "$2" ]]; then
        echo -e "${FAIL_LOG}    $1 requires exactly 1 argument (username of dynamic dns credential)"
        exit 1
      else
        USERNAME=$2
      fi
      shift
      shift
      ;;
    -p | --password)
      if [[ -z "$2" ]]; then
        echo -e "${FAIL_LOG}    $1 requires exactly 1 argument (password of dynamic dns credential)"
        exit 1
      else
        PASSWORD=$2
      fi
      shift
      shift
      ;;
    -h | --hostname)
      if [[ -z "$2" ]]; then
        echo -e "${FAIL_LOG}    $1 requires exactly 1 argument (hostname or domain name)"
        exit 1
      else
        HOST_NAME=$2
      fi
      shift
      shift
      ;;
    --help)
      echo -e "*************${CYAN} USAGE ${NC}*************"
      echo -e "    -h | --hostname    Hostname of the SSH remote server"
      echo -e "    -u | --username    Username of the Dynamic DNS account"
      echo -e "    -p | --password    Password of the Dynamic DNS account"
      shift
      exit 0
      ;;
  esac
done
if [[ -z "${USERNAME}" || -z "${PASSWORD}" || -z "${HOST_NAME}" ]]; then
  echo -e "${FAIL_LOG}    Hostname, Username and password of dynamic ddns credential is mandatory"
  exit 1
fi
if [[ -z "${MODE}" ]]; then
  SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
  FILE_NAME=$(basename $0)
  sudo cp ${SCRIPT_DIR}/${FILE_NAME} /usr/bin/
  sudo chmod +x /usr/bin/${FILE_NAME}
  sudo touch /lib/systemd/system/userddns.service
  sudo sh -c "echo \
\"[Unit]
Description=Dynamic DNS Service

[Service]
ExecStart=/usr/bin/${FILE_NAME} -m service -u ${USERNAME} -p ${PASSWORD} -h ${HOST_NAME}

[Install]
WantedBy=multi-user.target\" \
> /lib/systemd/system/userddns.service" > /dev/null
  sudo systemctl daemon-reload
  sudo systemctl enable userddns.service
  sudo systemctl start userddns.service
  sudo systemctl status userddns.service
  exit 0  
fi
CACHED_IP=0
if [[ "${MODE}" == "service" ]]; then
  while true
  do
    PUBLIC_IP=$(curl --max-time 1 --connect-timeout 0.5 "ipinfo.io/ip")
    if [[ $? -ne 0 ]]; then
      PUBLIC_IP=$(curl --max-time 1 --connect-timeout 0.5 "ifconfig.me")
    fi
    if [[ "${CACHED_IP}" != "${PUBLIC_IP}" ]]; then
      curl --max-time 1.5 --connect-timeout 0.5 "https://${USERNAME}:${PASSWORD}@domains.google.com/nic/update?hostname=${HOST_NAME}&myip=${PUBLIC_IP}"
      CACHED_IP=${PUBLIC_IP}
    fi
    sleep 1s
  done
fi
