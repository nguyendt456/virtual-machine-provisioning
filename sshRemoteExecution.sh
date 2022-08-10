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

ssh altus "\
cat ~/.ssh/authorized_keys 2>1 > /dev/null
if [[ $? -ne 0 ]]; then
    cat ~/.ssh/authorized_keys | grep \"${USER}@${HOSTNAME}\";
  if [[ $? -ne 0 ]]; then
    cat - >> ~/.ssh/authorized_keys;
  else
    echo -e \"${SUCCESS_LOG}    Finish setup authorized key. Now you can login without password\"
  fi
else
  touch ~/.ssh/authorized_keys && cat - >> ~/.ssh/authorized_keys
  echo -e \"${SUCCESS_LOG}    Finish setup authorized key. Now you can login without password\"
fi;\
" < ~/.ssh/id_rsa.pub