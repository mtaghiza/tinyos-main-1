#!/bin/bash
# install root on USB0
# install leaf on USB1


enablePrintf=1
#enable auto push
eap=0
#router power
rp=0x2D
#leaf power
lp=0x2D
rxSlack=15UL
txSlack=44UL
gitRev=$(git log --pretty=format:'%h' -n 1)
#enable forwarder selection
efs=0
#frames per slot
fps=30
#boundary width
bw=2
#probe interval
pi=1024
#global channel
gc=128
#router channel
rc=0
#data rate
dr=0
#test payload len
tpl=64
#enable auto-sender
eas=0
#enable testbed (replaces auto-sender)
etb=1
#max attempts
ma=2
#max download rounds
mdr=1
#missed CTS threshold
mct=4
#self sfd synch
ssfds=1
#power adjust (decrease power on retx)
pa=1
#max depth
md=10
#enable configurable lognotify
ecl=0
#high push threshold
hpt=1
td=0xFFFF
dls=DL_INFO
dlsr=DL_INFO
map=map.flat
#test segment: default= subnetwork(flat)
ts=1
#packets per download
ppd=0
tdel=61440UL
sdel=92160UL
#max tx
mt=1

settingVars=( "rp" "lp" "rxSlack" "txSlack" "gitRev"
"efs" "fps" "bw" "pi"
"gc" "rc" "installTS" "dr" "tpl" "td" "eas" "etb" "ma" "mdr" "dls" "dlsr"
"mct" "ssfds" "pa" "md" "ecl" "hpt" "tpl" "map" "ppd" "tdel" "ts"
"sdel" "mt")

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

if [ $installTS -eq 0 ]
then
  installTS=$(date +%s)
fi

testDesc=""
for v in ${settingVars[@]}
do
  testDesc=${testDesc}_${v//_/-}_${!v//_/-}
done

#trim off the leading underscore
testDescFull=$(echo "$testDesc" | cut -c 1 --complement)

#shorten that down bigtime
testDescShort=installTS_${installTS}

echo "Router: ${testDescRouter}"
echo "Leaf: ${testDescLeaf}"
echo "root: ${testDescRoot}"
set -x
#for map in map.p0
#for map in map.p0 map.p1 map.p2 map.p3
snc=0
    commonOptions="RX_SLACK=$rxSlack\
      TX_SLACK=$txSlack\
      ENABLE_FORWARDER_SELECTION=$efs\
      FRAMES_PER_SLOT=$fps\
      CX_MAX_DEPTH=$md\
      STATIC_BW=$bw\
      LPP_DEFAULT_PROBE_INTERVAL=${pi}UL\
      GLOBAL_CHANNEL=$gc\
      ROUTER_CHANNEL=$rc\
      SUBNETWORK_CHANNEL=$snc\
      ENABLE_AUTOPUSH=$eap\
      DL_STATS=$dls\
      DL_STATS_RADIO=$dlsr\
      DL_TESTBED=DL_INFO\
      DL_GLOBAL=DL_DEBUG\
      DL_SCHED=DL_WARN\
      DL_AM=DL_WARN\
      TEST_DATA_RATE=$dr\
      TEST_PAYLOAD_LEN=$tpl\
      TEST_DESTINATION=$td\
      ENABLE_AUTOSENDER=$eas\
      ENABLE_PROBE_SCHEDULE_CONFIG=0\
      ENABLE_BACON_SAMPLER=0\
      ENABLE_TOAST_SAMPLER=0\
      ENABLE_PHOENIX=0\
      ENABLE_SETTINGS_CONFIG=0\
      ENABLE_SETTINGS_LOGGING=0\
      ENABLE_CONFIGURABLE_LOG_NOTIFY=$ecl\
      DEFAULT_HIGH_PUSH_THRESHOLD=$hpt\
      DEFAULT_MAX_DOWNLOAD_ROUNDS=$mdr\
      DEFAULT_MAX_ATTEMPTS=$ma\
      SELF_SFD_SYNCH=$ssfds\
      POWER_ADJUST=$pa\
      MISSED_CTS_THRESH=$mct\
      ENABLE_TESTBED=$etb\
      PACKETS_PER_DOWNLOAD=$ppd\
      STARTUP_DELAY=$sdel\
      TEST_DELAY=$tdel\
      TEST_SEGMENT=$ts\
      CC430_PIN_DEBUG=1\
      MAX_TX=$mt\
      ENABLE_PRINTF=$enablePrintf"

    pushd .
    testDesc=\\\"${testDescShort}_snc_${snc}\\\"
    cd ../Leaf
    make bacon2 -f Makefile.testbed \
      MAX_POWER=$lp\
      TEST_DESC=$testDesc\
      $commonOptions install bsl,/dev/ttyUSB1 || exit 1
    popd
    testDesc=\\\"${testDescShort}_snc_${snc}\\\"
    make bacon2 \
      MAX_POWER=$rp\
      TEST_DESC=$testDesc\
      $commonOptions install bsl,/dev/ttyUSB0 || exit 1
