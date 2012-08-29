#!/bin/bash
autoRun=1
programDelay=60
if [ $# -eq 0 ]
then 
  echo "No test name provided." 1>&2
  exit 1
fi
testDesc=\\\"$1\\\"
shift 1

rootMap=map.root
receiverMap=map.nonroot.rx
senderMap=map.nonroot.tx

#radio physical params
txp=0xC3
tc=0

debugScale=4UL

#test setup
requestAck=0
rootSender=0
rootDest=1
senderDest=0

fecEnabled=0
fecHamming74=1

targetIpi=1024UL
queueThreshold=10

#network params
fps=40
maxDepth=5
numTransmits=1
staticScheduler=1
bufferWidth=0

#radio logging
rl=0
rs=1

#schedule config
#init symbol rate
sr=125

#stack protection
sp=1
#pool size
ps=3

debugLinkRXTX=1
debugFCleartime=0
debugSFCleartime=0
debugTestbed=1
debugPacket=0
sv=0
pr=0
sfr=0
crc=0
debugConfig=0
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
debugRoutingTable=0
debugUB=1

while [ $# -gt 1 ]
do
  case $1 in
   testId)
     testId=$2
     shift 2
   ;;
   testLabel)
     testLabel=$2
     shift 2
   ;;
   txp)
     txp=$2
     shift 2
   ;;
   sr)
     sr=$2
     shift 2
   ;;
   channel)
     channel=$2
     shift 2
   ;;
   requestAck)
     requestAck=$2
     shift 2
   ;;
   senderDest)
     senderDest=$2
     shift 2
     ;;
   senderMap)
     senderMap=$2
     shift 2
     ;;
   receiverMap)
     receiverMap=$2
     shift 2
     ;;
   rootMap)
     rootMap=$2
     shift 2
     ;;
   targetIpi)
     targetIpi=$2
     shift 2
     ;;
   queueThreshold)
     queueThreshold=$2
     shift 2
     ;;
   maxDepth)
     maxDepth=$2
     shift 2
     ;;
   numTransmits)
     numTransmits=$2
     shift 2
     ;;
   bufferWidth)
     bufferWidth=$2
     shift 2
     ;;
   fps)
     fps=$2
     shift 2
     ;;
   staticScheduler)
     staticScheduler=$2
     shift 2
   ;;
   *)
     echo "unrecognized: $1"
     shift 1
   ;;
  esac
done


set -x 
if [ $staticScheduler -eq 1 ]
then
  maxNodeId=$(cat $rootMap $receiverMap $senderMap | grep -v '#' | sort -n -k 2 | tail -1 | cut -d ' ' -f 2)
  numSlots=$(($maxNodeId + 10))
  firstIdleSlot=$(($maxNodeId + 5))
else
  numNodes=$(cat $rootMap $receiverMap $senderMap | grep -c -v '#' )
  numSlots=$(($numNodes + 5))
  firstIdleSlot=0
fi

scheduleOptions="DEBUG_SCALE=$debugScale TA_DIV=1UL SCHED_INIT_SYMBOLRATE=$sr DISCONNECTED_SR=500 SCHED_MAX_DEPTH=${maxDepth}UL SCHED_FRAMES_PER_SLOT=$fps SCHED_NUM_SLOTS=$numSlots SCHED_MAX_RETRANSMIT=${numTransmits}UL STATIC_SCHEDULER=$staticScheduler STATIC_FIRST_IDLE_SLOT=$firstIdleSlot CX_BUFFER_WIDTH=$bufferWidth CX_DUTY_CYCLE_ENABLED=1"
set +x
phyOptions="PATABLE0_SETTING=$txp TEST_CHANNEL=$tc"

memoryOptions="STACK_PROTECTION=$sp CX_MESSAGE_POOL_SIZE=$ps"

loggingOptions="CX_RADIO_LOGGING=$rl DEBUG_RADIO_STATS=$rs"

debugOptions="DEBUG_F_STATE=0 DEBUG_SF_STATE=0  DEBUG_F_TESTBED=0 DEBUG_SF_SV=$sv DEBUG_F_SV=$sv DEBUG_SF_TESTBED_PR=$pr DEBUG_SF_ROUTE=$sfr DEBUG_TESTBED_CRC=$crc DEBUG_AODV_CLEAR=$aodvClear DEBUG_TEST_QUEUE=1 DEBUG_RXREADY_ERROR=$rxr DEBUG_PACKET=$debugPacket DEBUG_CONFIG=$debugConfig DEBUG_TDMA_SS=$debugSS DEBUG_FEC=$debugFEC DEBUG_SF_RX=$debugSFRX DEBUG_TESTBED_RESOURCE=$debugTestbedResource DEBUG_TESTBED=$debugTestbed DEBUG_LINK_RXTX=$debugLinkRXTX DEBUG_F_CLEARTIME=$debugFCleartime DEBUG_SF_CLEARTIME=$debugSFCleartime DEBUG_DUP=$debugDup DEBUG_F_SCHED=$debugFSched DEBUG_ROUTING_TABLE=$debugRoutingTable DEBUG_UB=$debugUB" 


testSettings="QUEUE_THRESHOLD=$queueThreshold TEST_IPI=$targetIpi CX_ADAPTIVE_SR=0 RF1A_FEC_ENABLED=$fecEnabled FEC_HAMMING74=$fecHamming74"
miscSettings="ENABLE_SKEW_CORRECTION=0 TEST_DESC=$testDesc"

commonOptions="$scheduleOptions $phyOptions $memoryOptions $loggingOptions $debugOptions $testSettings $miscSettings"

set -x 

pushd .
testbedDir=$(pwd)
cd ~/tinyos-2.x/apps/Blink
./burn $testbedDir/map.bacon2 2>&1 | grep -i -e err -e sensorbed
popd

if [ $autoRun == 0 ]
then
  read -p "Hit enter when programming is done"
else
  sleep $programDelay
fi

if [ "$receiverMap" != "" ]
then
  ./burn $receiverMap \
    TDMA_ROOT=0 IS_SENDER=0 \
    $commonOptions 
fi

if [ "$senderMap" != "" ]
then
  ./burn $senderMap \
    TDMA_ROOT=0 IS_SENDER=1 \
    TEST_DEST_ADDR=$senderDest \
    TEST_REQUEST_ACK=$requestAck\
    $commonOptions
fi

if [ "$rootMap" != "" ]
then
  ./burn $rootMap \
    TDMA_ROOT=1 IS_SENDER=$rootSender \
    TEST_DEST_ADDR=$rootDest \
    TEST_REQUEST_ACK=$requestAck\
    $commonOptions
fi
