#!/bin/bash
retries=10
retryTimeout=30
locked=0
for i in $(seq $retries)
do
  if [ -f install_lock ]
  then
    echo "install_lock present, retry in $retryTimeout s"
    sleep $retryTimeout
  else
    echo "locking installation directory"
    locked=1
    touch install_lock
    break
  fi
done
if [ $locked -eq 0 ]
then
  echo "COULD NOT OBTAIN LOCK ON INSTALLATION DIRECTORY!" 1>&2
  exit 1
fi

killall picocom
autoRun=1
programDelay=30

debugScale=4UL

rootSender=0
rootDest=1

#radio logging
rl=0
rs=1

#stack protection
sp=1
#pool size
ps=3

#debug settings
debugLinkRXTX=1
debugFCleartime=1
debugSFCleartime=0
debugTestbed=1
debugPacket=0
sv=0
pr=0
sfr=0
crc=0
txAodvState=0
rxAodvState=0
aodvClear=0
debugFEC=0
debugSFRX=0
debugSS=0
debugTestbedResource=0
#debug RXREADY error messages
rxr=0
debugDup=0
debugFSched=0
debugRoutingTable=1
debugUB=1

#test defaults
testId=$(date +%s)
testLabel=''
sr=125
channel=0
requestAck=0
senderDest=65535UL
senderMap=dmap/dmap.none
receiverMap=dmap/dmap.1
receiverMap2=dmap/dmap.none
rootMap=dmap/dmap.0
snifferMap=dmap/dmap.none
targetIpi=1024UL
queueThreshold=10
maxDepth=5
numTransmits=1
bufferWidth=0
fps=40
staticScheduler=1
forceSlots=0
cxEnableSkewCorrection=1
fwdDropRate=0
cxForwarderSelection=0
cxSniffEnabled=0
cxFixedLen=0
maxAnnouncedSlots=0
fecEnabled=0
minimalPacket=1
fecHamming74=1
debugConfig=0

settingVars=( "testId" "testLabel" "sr" "channel" "requestAck"
"senderDest" "senderMap" "receiverMap" "rootMap" "targetIpi"
"queueThreshold" "maxDepth" "numTransmits" "bufferWidth" "fps"
"staticScheduler" "snifferMap" "forceSlots" "cxEnableSkewCorrection"
"fwdDropRate" "cxForwarderSelection" "receiverMap2" "cxSniffEnabled" 
"cxFixedLen" "maxAnnouncedSlots" "fecEnabled" "fecHamming74"
"debugConfig" "minimalPacket")

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
    rm install_lock
    exit 1
  fi
done

for v in ${settingVars[@]}
do
  echo "SETTING $v VALUE [${!v}]"
done

if [ "$testLabel" == "" ]
then
  echo "No test label provided." 1>&2
  rm install_lock
  exit 1
fi

#concatenate the settings together
testDesc=""
for v in ${settingVars[@]}
do
  testDesc=${testDesc}_${v}_${!v}
done
#trim off the leading underscore
testDesc=$(echo "$testDesc" | cut -c 1 --complement)
#and slap it into something that make won't barf on
testDesc=\\\"$testDesc\\\"

if [ $staticScheduler -eq 1 ]
then
  if [ "$forceSlots" !=  "0" ]
  then
    numSlots=$forceSlots
    firstIdleSlot=$(($forceSlots - 1))
  else
    maxNodeId=$(cat $rootMap $receiverMap $senderMap | grep -v '#' | sort -n -k 2 | tail -1 | cut -d ' ' -f 2)
    numSlots=$(($maxNodeId + 10))
    firstIdleSlot=$(($maxNodeId + 5))
  fi
else
  numNodes=$(cat $rootMap $receiverMap $senderMap | grep -c -v '#' )
  numSlots=$(($numNodes + 5))
  firstIdleSlot=0
fi

scheduleOptions="DEBUG_SCALE=$debugScale TA_DIV=1UL SCHED_INIT_SYMBOLRATE=$sr DISCONNECTED_SR=500 SCHED_MAX_DEPTH=${maxDepth}UL SCHED_FRAMES_PER_SLOT=$fps SCHED_NUM_SLOTS=$numSlots SCHED_MAX_RETRANSMIT=${numTransmits}UL STATIC_SCHEDULER=$staticScheduler STATIC_FIRST_IDLE_SLOT=$firstIdleSlot CX_BUFFER_WIDTH=$bufferWidth CX_DUTY_CYCLE_ENABLED=1 CX_ENABLE_SKEW_CORRECTION=$cxEnableSkewCorrection CX_FORWARDER_SELECTION=$cxForwarderSelection MAX_ANNOUNCED_SLOTS=$maxAnnouncedSlots"
phyOptionsCommon="TEST_CHANNEL=$channel CX_SNIFF_ENABLED=$cxSniffEnabled CX_FIXED_LEN=$cxFixedLen"

memoryOptions="STACK_PROTECTION=$sp CX_MESSAGE_POOL_SIZE=$ps"

loggingOptions="CX_RADIO_LOGGING=$rl DEBUG_RADIO_STATS=$rs"

debugOptions="DEBUG_F_STATE=0 DEBUG_SF_STATE=0  DEBUG_F_TESTBED=0 DEBUG_SF_SV=$sv DEBUG_F_SV=$sv DEBUG_SF_TESTBED_PR=$pr DEBUG_SF_ROUTE=$sfr DEBUG_TESTBED_CRC=$crc DEBUG_AODV_CLEAR=$aodvClear DEBUG_TEST_QUEUE=1 DEBUG_RXREADY_ERROR=$rxr DEBUG_PACKET=$debugPacket DEBUG_CONFIG=$debugConfig DEBUG_TDMA_SS=$debugSS DEBUG_FEC=$debugFEC DEBUG_SF_RX=$debugSFRX DEBUG_TESTBED_RESOURCE=$debugTestbedResource DEBUG_TESTBED=$debugTestbed DEBUG_LINK_RXTX=$debugLinkRXTX DEBUG_F_CLEARTIME=$debugFCleartime DEBUG_SF_CLEARTIME=$debugSFCleartime DEBUG_DUP=$debugDup DEBUG_F_SCHED=$debugFSched DEBUG_ROUTING_TABLE=$debugRoutingTable DEBUG_UB=$debugUB" 

#remove extraneous header fields if FEC is enabled
testSettings="QUEUE_THRESHOLD=$queueThreshold TEST_IPI=$targetIpi CX_ADAPTIVE_SR=0 RF1A_FEC_ENABLED=$fecEnabled FEC_HAMMING74=$fecHamming74 FWD_DROP_RATE=$fwdDropRate MINIMAL_PACKET=$minimalPacket"
miscSettings="ENABLE_SKEW_CORRECTION=0 TEST_DESC=$testDesc"

commonOptions="$scheduleOptions $phyOptionsCommon $memoryOptions $loggingOptions $debugOptions $testSettings $miscSettings"


pushd .
testbedDir=$(pwd)
cd ~/tinyos-2.x/apps/Blink

make bacon2
for dev in /dev/ttyUSB*
do
  make bacon2 reinstall bsl,$dev
done
popd

if [ $autoRun == 0 ]
then
  read -p "Hit enter when programming is done"
else
  echo "moving right along"
fi

tf=$(tempfile)
cat $receiverMap $receiverMap2 > $tf

if [ "$tf" != ""  -a $(grep -c -v '#' $tf) -gt 0 ]
then
  grep -v '#' $tf | while read line
  do
    ref=$(echo $line | cut -d ' ' -f 1)
    id=$(echo $line | cut -d ' ' -f 2)
    txp=$(echo $line | cut -d ' ' -f 3)

    phyOptionsLeaf="PATABLE0_SETTING=$txp"
    make bacon2 \
      TDMA_ROOT=0 IS_SENDER=0 \
      $commonOptions \
      $phyOptionsLeaf \
      install,$id bsl,ref,$ref
  done
fi
rm $tf

if [ "$senderMap" != "" -a $(grep -c -v '#' $senderMap) -gt 0 ]
then
  grep -v '#' $senderMap | while read line
  do
    ref=$(echo $line | cut -d ' ' -f 1)
    id=$(echo $line | cut -d ' ' -f 2)
    txp=$(echo $line | cut -d ' ' -f 3)
    phyOptionsLeaf="PATABLE0_SETTING=$txp"
    
    make bacon2 \
      TDMA_ROOT=0 IS_SENDER=1 \
      TEST_DEST_ADDR=$senderDest \
      TEST_REQUEST_ACK=$requestAck\
      $commonOptions \
      $phyOptionsLeaf\
      install,$id bsl,ref,$ref
  done
fi

if [ "$snifferMap" != "" -a $(grep -c -v '#' $snifferMap) -gt 0 ]
then
  pushd .
  cd ../sniffer
  make bacon2
  grep -v '#' ../cxActiveMessage/$snifferMap | while read line
  do
    ref=$(echo $line | cut -d ' ' -f 1)
    id=$(echo $line | cut -d ' ' -f 2)
    set -x
    make bacon2 TEST_CHANNEL=$channel SYMBOLRATE=$sr install,$id bsl,ref,$ref
    set +x
  done
  popd
fi

if [ "$rootMap" != "" -a $(grep -c -v '#' $rootMap) -gt 0 ]
then

  grep -v '#' $rootMap | while read line
  do
    ref=$(echo $line | cut -d ' ' -f 1)
    id=$(echo $line | cut -d ' ' -f 2)
    txp=$(echo $line | cut -d ' ' -f 3)
    phyOptionsRoot="PATABLE0_SETTING=$txp"
    make bacon2 \
      TDMA_ROOT=1 IS_SENDER=$rootSender \
      TEST_DEST_ADDR=$rootDest \
      TEST_REQUEST_ACK=$requestAck\
      $commonOptions\
      $phyOptionsRoot\
      install,$id bsl,ref,$ref
  done
fi

rm install_lock
