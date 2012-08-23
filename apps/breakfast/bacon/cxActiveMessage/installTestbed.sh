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

root=map.root
nonrootRx=map.nonroot.rx
nonrootTx=map.nonroot.tx

#radio physical params
txp=0xC3
tc=0

debugScale=4UL

#test setup
testRequestAck=0
rootSender=0
rootDest=1
leafDest=0

fecEnabled=0
fecHamming74=1

ipi=1024UL
queueThreshold=10

#network params
fps=40
md=5
mr=1
staticScheduler=1
cxBufferWidth=0

#radio logging
rl=0
rs=0

#schedule config
#init symbol rate
initSR=125

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
   staticScheduler)
     staticScheduler=$2
     shift 2
   ;;
   nonrootTx)
     nonrootTx=$2
     shift 2
     ;;
   nonrootRx)
     nonrootRx=$2
     shift 2
     ;;
   testRequestAck)
     testRequestAck=$2
     shift 2
     ;;
   cxBufferWidth)
     cxBufferWidth=$2
     shift 2
     ;;
   mr)
     mr=$2
     shift 2
     ;;
   leafDest)
     leafDest=$2
     shift 2
     ;;
   fps)
     fps=$2
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
  maxNodeId=$(cat $root $nonrootRx $nonrootTx | grep -v '#' | sort -n -k 2 | tail -1 | cut -d ' ' -f 2)
  numSlots=$(($maxNodeId + 10))
  firstIdleSlot=$(($maxNodeId + 5))
else
  numNodes=$(cat $root $nonrootRx $nonrootTx | grep -c -v '#' )
  numSlots=$(($numNodes + 5))
  firstIdleSlot=0
fi

scheduleOptions="DEBUG_SCALE=$debugScale TA_DIV=1UL SCHED_INIT_SYMBOLRATE=$initSR DISCONNECTED_SR=500 SCHED_MAX_DEPTH=${md}UL SCHED_FRAMES_PER_SLOT=$fps SCHED_NUM_SLOTS=$numSlots SCHED_MAX_RETRANSMIT=${mr}UL STATIC_SCHEDULER=$staticScheduler STATIC_FIRST_IDLE_SLOT=$firstIdleSlot CX_BUFFER_WIDTH=$cxBufferWidth"
set +x
phyOptions="PATABLE0_SETTING=$txp TEST_CHANNEL=$tc"

memoryOptions="STACK_PROTECTION=$sp CX_MESSAGE_POOL_SIZE=$ps"

loggingOptions="CX_RADIO_LOGGING=$rl DEBUG_RADIO_STATS=$rs"

debugOptions="DEBUG_F_STATE=0 DEBUG_SF_STATE=0  DEBUG_F_TESTBED=0 DEBUG_SF_SV=$sv DEBUG_F_SV=$sv DEBUG_SF_TESTBED_PR=$pr DEBUG_SF_ROUTE=$sfr DEBUG_TESTBED_CRC=$crc DEBUG_AODV_CLEAR=$aodvClear DEBUG_TEST_QUEUE=1 DEBUG_RXREADY_ERROR=$rxr DEBUG_PACKET=$debugPacket DEBUG_CONFIG=$debugConfig DEBUG_TDMA_SS=$debugSS DEBUG_FEC=$debugFEC DEBUG_SF_RX=$debugSFRX DEBUG_TESTBED_RESOURCE=$debugTestbedResource DEBUG_TESTBED=$debugTestbed DEBUG_LINK_RXTX=$debugLinkRXTX DEBUG_F_CLEARTIME=$debugFCleartime DEBUG_SF_CLEARTIME=$debugSFCleartime DEBUG_DUP=$debugDup DEBUG_F_SCHED=$debugFSched DEBUG_ROUTING_TABLE=$debugRoutingTable DEBUG_UB=$debugUB" 


testSettings="QUEUE_THRESHOLD=$queueThreshold TEST_IPI=$ipi CX_ADAPTIVE_SR=0 RF1A_FEC_ENABLED=$fecEnabled FEC_HAMMING74=$fecHamming74"
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

if [ "$nonrootRx" != "" ]
then
  ./burn $nonrootRx \
    TDMA_ROOT=0 IS_SENDER=0 \
    $commonOptions 
fi

if [ "$nonrootTx" != "" ]
then
  ./burn $nonrootTx \
    TDMA_ROOT=0 IS_SENDER=1 \
    TEST_DEST_ADDR=$leafDest \
    TEST_REQUEST_ACK=$testRequestAck\
    $commonOptions
fi

if [ "$root" != "" ]
then
  ./burn $root \
    TDMA_ROOT=1 IS_SENDER=$rootSender \
    TEST_DEST_ADDR=$rootDest \
    TEST_REQUEST_ACK=$testRequestAck\
    $commonOptions
fi
