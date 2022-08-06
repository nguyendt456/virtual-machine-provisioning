#!/bin/bash
# @Author: nguyendt456
###############################################
# Automate setup env for set up virtual machine
# Usage: chmod +x <this file>
#        ./<this file>
###############################################


RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'
FAIL_LOG="${RED}FAIL${NC} "
SUCCESS_LOG="${GREEN}SUCCESS${NC}"
INFO_LOG="[${CYAN}INFO${NC}] "

while [[ $# -gt 0 ]]; do
case $1 in
  -ip | --static-ip)
    if [[ -z "$2" ]]; then
      echo -e "${FAIL_LOG}    $1 takes exactly one argument (static IP address of ur VM and subnet)"
      exit 1
    else
      static_ip=$2
    fi
    shift
    shift
    ;;
  -gw | --gate-way-ip)
    if [[ -z "$2" ]]; then
      echo -e "${FAIL_LOG}    $1 takes exactly one argument (gateway ip or router ip)"
      exit 1
    else
      gateway_ip=$2
    fi
    shift
    shift
    ;;
  -h | --help)
    echo -e "***[${CYAN}Help${NC}]***"
    echo -e "    -ip | --static-ip     IP address of virtual machine and subnet (Example: 192.168.1.233/24)"
    echo -e "    -gw | --gate-way-ip   Default gateway IP address or router IP"
    ;;
  *)
    echo -e "${FAIL_LOG}    Invalid argument ! Checking the usage by execute the command with -h or --help"
    exit 1
    ;;
esac
done

validateEssentialVariable () {
  if [[ -z ${static_ip+x} || -z ${gateway_ip+x} ]]; then
    echo -e "${FAIL_LOG}    Missing static IP address or default gateway ip (router ip)"
    exit 1
  fi
  echo -e "${SUCCESS_LOG}    Detected static IP address and default gateway ip (router ip)"
  echo -e "\n    * Static IP address:           ${static_ip}"
  echo -e "    * Default gateway IP address:  ${gateway_ip}\n"
}

netplanInitialize () {
  $(echo -e "${INFO_LOG}    Initial network plan" > /dev/stderr)
  echo -e "${INFO_LOG}    Remove current netplan"
  $(sudo rm -f /etc/netplan/*)
  if [[ $? -ne 0 ]]; then
    echo -e "${FAIL_LOG}    Fail when delete current netplan directory" > /dev/stderr
    exit 1
  else
    echo -e "${SUCCESS_LOG}    Removed current netplan directory" > /dev/stderr
  fi
  NETWORK_INTERFACE=$(lshw -class network 2> /dev/null | grep 'logical name:' | sed "s/logical name: //g;s/ //g" | grep 'enp') > /dev/null
  DEFAULT_GW_MESSAGE=$(ip r | grep 'default via') > /dev/null
  IFS=' ' read -r -a gw_message_arr <<< "${DEFAULT_GW_MESSAGE}"
  CURRENT_DEFAULT_GW=${gw_message_arr[2]}
  IFS='.' read -r -a gw_arr <<< "${CURRENT_DEFAULT_GW}"
  prefixIP_3="${gw_arr[0]}.${gw_arr[1]}.${gw_arr[2]}\."
  IPv4_RAW=$(ip a | grep -w 'inet' | grep "${prefixIP_3}")
  if [[ $? -ne 0 ]]; then
    unset IPv4
    prefixIP_2="${gw_arr[0]}.${gw_arr[1]}\."
    IPv4_RAW=$(ip a | grep -w 'inet' | grep "${prefixIP_2}")
    IPv4=${ipv4[1]}
  else
    IFS=' ' read -r -a ipv4 <<< "${IPv4_RAW}"
    IPv4=${ipv4[1]}
  fi
  if [[ -z "${NETWORK_INTERFACE}" ]]; then
    $(echo -e "${FAIL_LOG}    Can't detect network interface" > /dev/stderr)
    exit 1 
  else
    $(echo -e "${SUCCESS_LOG}    Detected network interface" > /dev/stderr)
    echo -e "\n    * Network interface controller:   ${NETWORK_INTERFACE}" > /dev/stderr
    echo -e "    * Current IP address:             ${IPv4}" > /dev/stderr
    echo -e "    * Current Default Gateway:        ${CURRENT_DEFAULT_GW}\n" > /dev/stderr
  fi
  sudo touch /etc/netplan/01-network-manager-all.yaml
  $(sudo sh -c "echo \
\"network:
  ethernets:
    ${NETWORK_INTERFACE}:
      dhcp4: false
  version: 2
  bridges:
    br0:
      interfaces: [${NETWORK_INTERFACE}]
      addresses: [${static_ip}]
      routes:
       - to: default
         via: ${gateway_ip}
      mtu: 1500
      parameters:
        stp: true
      dhcp4: no\" \
    > /etc/netplan/01-network-manager-all.yaml" > /dev/null)
  sudo netplan generate
  if [[ $? -ne 0 ]]; then
    echo -e "${FAIL_LOG}    Fail when generate netplan" > /dev/stderr
    exit 1
  else
    echo -e "${SUCCESS_LOG}    Generated netplan configuration" > /dev/stderr
  fi
  if [[ "${IPv4}" != "${static_ip}" ]]; then
    echo -e "${INFO_LOG}    Detect current IP different to desired IP" > /dev/stderr
    echo -e "\n    * Netplan will be applied in 3 seconds" > /dev/stderr
    echo -e "    * SSH will logout now. SSH to the new IP address\n" > /dev/stderr
    sudo echo "sleep 3s; sudo netplan apply" | sudo at now 2> /dev/null
    sleep 1s
    pkill -9 -t pts/0 
  else
    sudo netplan apply
  fi
  if [[ $? -ne 0 ]]; then
    echo -e "${FAIL_LOG}    Fail when apply netplan" > /dev/stderr
  else
    echo -e "${SUCCESS_LOG}    Success apply new network configuration" > /dev/stderr
  fi
}
echo -e "\n############ ${CYAN}SETTING UP ENVIRONMENT${NC} ############\n"
validateEssentialVariable
echo -e "${INFO_LOG}    Installing packages for virtual environment"
message=$(sudo apt-get install -y qemu-system-x86 libvirt-daemon-system libvirt-clients bridge-utils virtinst at > /dev/stderr)
if [[ $? -ne 0 ]]; then
  echo -e "\n\n${FAIL_LOG}    Failed when install package"
  exit 1
else
  echo -e "\n\n${SUCCESS_LOG}    Successfully install package"
fi
echo -e "${INFO_LOG}    Add user to libvirt and kvm group"
$(sudo adduser ${USER} libvirt 1> /dev/null)
status=$?
$(sudo adduser ${USER} kvm 1> /dev/null)
if [[ $? -ne 0 || ${status} -ne 0 ]]; then
  echo -e "${FAIL_LOG}    Failed when add user to group"
  unset status
  exit 1
else
  echo -e "${SUCCESS_LOG}    Successfully added user to group"
fi
$(sudo systemctl status libvirtd | grep 'active (running)' > /dev/null)
if [[ $? -ne 0 ]]; then
  echo -e "${FAIL_LOG}    libvirtd service not ready"
  exit 1
else
  echo -e "${SUCCESS_LOG}    libvirtd service ready for use"
fi
echo -e "\n############## ${CYAN}SETTING UP NETWORK${NC} ###############\n"
netplanInitialize
brctl show | grep -w 'br0' > /dev/null
if [[ $? -ne 0 ]]; then
  echo -e "${FAIL_LOG}    Can't detect bridge"
  exit 1
else
  echo -e "${SUCCESS_LOG}    Detected bridge interface br0"
fi
echo -e '\nList of virtual devices:\n'
echo -e "************************************"
message=$(virsh list --all)
printf "${message}\n\n"
echo -e "************************************\n"
exit 0
