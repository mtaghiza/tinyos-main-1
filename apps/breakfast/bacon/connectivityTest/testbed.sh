#!/bin/bash

channel=0
#leaf power (all nodes, but whatever)
lp=0x2D
#11: CTS packet
#64: smallest normal packet
tpl=11
gitRev=$(git log --pretty=format:'%h' -n 1)
installTS=$(date +%s)
settingVars=( "lp" "gitRev" "tpl" "channel" "installTS")


while [ $# -gt 1 ]
do
  varMatched=0
  for v in ${settingVars[@]}
  do
    if [ "$v" == "$1" ]
    then
      varMatched=1
      declare "$1"="$2"
      shift 2
      break 
    fi
  done
  if [ $varMatched -eq 0 ]
  then
    echo "Unrecognized option $1. Options: ${settingVars[@]}" 1>&2
    exit 1
  fi
done

testDesc=""
for v in ${settingVars[@]}
do
  testDesc=${testDesc}_${v//_/-}_${!v//_/-}
done

#trim off the leading underscore
testDesc=$(echo "$testDesc" | cut -c 1 --complement)

testDescRouter=${testDesc}_role_router
testDescLeaf=${testDesc}_role_leaf
testDescRoot=${testDesc}_role_root

commonOptions="PAYLOAD_LEN=$tpl TEST_CHANNEL=$channel TEST_POWER=$lp"

./burn map.bacon2 $commonOptions TEST_DESC=\\\"$testDesc\\\"
