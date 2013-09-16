#!/bin/bash


enablePrintf=1
enableBaconSampler=0
eap=0

rp=0xC3
lp=0x2D
rxSlack=20UL
txSlack=100UL
gitRev=$(git log --pretty=format:'%h' -n 1)
efs=0
fps=30
bw=2
pi=1024
gc=0
rc=64
installTS=$(date +%s)

settingVars=( "rp" "lp" "rxSlack" "txSlack" "gitRev"
"efs" "fps" "bw" "pi"
"gc" "rc" "installTS")

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
  testDesc=${testDesc}_${v}_${!v}
done

#trim off the leading underscore
testDesc=$(echo "$testDesc" | cut -c 1 --complement)

testDescRouter=${testDesc}_role_router
testDescLeaf=${testDesc}_role_leaf

echo "Router: ${testDescRouter}"
echo "Leaf: ${testDescLeaf}"

for map in map.p0
#for map in map.p0 map.p1 map.p2 map.p3
do
  snc=$(grep SNC $map | cut -d ' ' -f 2)

  testDesc=\\\"${testDescRouter}_snc_${snc}\\\"

  ./burnRole.sh $map Router\
    MAX_POWER=$rp\
    RX_SLACK=$rxSlack\
    TX_SLACK=$txSlack\
    ENABLE_FORWARDER_SELECTION=$efs\
    FRAMES_PER_SLOT=$fps\
    STATIC_BW=$bw\
    LPP_DEFAULT_PROBE_INTERVAL=${pi}UL\
    GLOBAL_CHANNEL=$gc\
    ROUTER_CHANNEL=$rc\
    SUBNETWORK_CHANNEL=$snc\
    ENABLE_AUTOPUSH=$eap\
    TEST_DESC=$testDesc\
    ENABLE_PRINTF=$enablePrintf || exit 1
  
  exit 0
  testDesc=\\\"${testDescLeaf}_snc_${snc}\\\"

  ./burnRole.sh $map Leaf -f Makefile.dummycxl \
    MAX_POWER=$lp\
    RX_SLACK=$rxSlack\
    TX_SLACK=$txSlack\
    ENABLE_FORWARDER_SELECTION=$efs\
    FRAMES_PER_SLOT=$fps\
    STATIC_BW=$bw\
    LPP_DEFAULT_PROBE_INTERVAL=${pi}UL\
    GLOBAL_CHANNEL=$gc\
    ROUTER_CHANNEL=$rc\
    SUBNETWORK_CHANNEL=$snc\
    ENABLE_BACON_SAMPLER=$enableBaconSampler\
    DEFAULT_SAMPLE_INTERVAL=61440UL\
    ENABLE_AUTOPUSH=$eap\
    TEST_DESC=$testDesc\
    ENABLE_PRINTF=$enablePrintf || exit 1
done  
