#!/bin/bash
if [ $# -eq 0 ]
then 
  echo "No test name provided." 1>&2
  exit 1
fi
testDesc=\\\"$1\\\"

#radio physical params
txp=0x25
tc=0


debugScale=4UL

#test setup
rootId="0"
#rootId=""
rootSender=0
rootDest=1
#nonrootRx="1"
leafDest=0
testRequestAck=0
#allPlugged="0 1 2 3"
allPlugged="0 1"
#allPlugged="0"
nonrootTx=""

fecEnabled=0
fecHamming74=1

ipi=1024UL
queueThreshold=1

#network params
numSlots=20
fps=5
md=1
mr=1
staticScheduler=1
firstIdleSlot=$2
cxBufferWidth=0

#radio logging
rl=0
rs=1

#schedule config
#init symbol rate
initSR=125

#stack protection
sp=1
#pool size
ps=3

debugLinkRXTX=0
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

killall picocom

pushd .
cd ~/tinyos-2.x/apps/Blink
make bacon2
for id in $allPlugged
do
  make bacon2 reinstall bsl,ref,JH00030$id
done
popd

scheduleOptions="DEBUG_SCALE=$debugScale TA_DIV=1UL SCHED_INIT_SYMBOLRATE=$initSR DISCONNECTED_SR=500 SCHED_MAX_DEPTH=${md}UL SCHED_FRAMES_PER_SLOT=$fps SCHED_NUM_SLOTS=$numSlots SCHED_MAX_RETRANSMIT=${mr}UL STATIC_SCHEDULER=$staticScheduler STATIC_FIRST_IDLE_SLOT=$firstIdleSlot CX_BUFFER_WIDTH=$cxBufferWidth"

phyOptions="PATABLE0_SETTING=$txp TEST_CHANNEL=$tc"

memoryOptions="STACK_PROTECTION=$sp CX_MESSAGE_POOL_SIZE=$ps"

loggingOptions="CX_RADIO_LOGGING=$rl DEBUG_RADIO_STATS=$rs"

debugOptions="DEBUG_F_STATE=0 DEBUG_SF_STATE=0  DEBUG_F_TESTBED=0 DEBUG_SF_SV=$sv DEBUG_F_SV=$sv DEBUG_SF_TESTBED_PR=$pr DEBUG_SF_ROUTE=$sfr DEBUG_TESTBED_CRC=$crc DEBUG_AODV_CLEAR=$aodvClear DEBUG_TEST_QUEUE=1 DEBUG_RXREADY_ERROR=$rxr DEBUG_PACKET=$debugPacket DEBUG_CONFIG=$debugConfig DEBUG_TDMA_SS=$debugSS DEBUG_FEC=$debugFEC DEBUG_SF_RX=$debugSFRX DEBUG_TESTBED_RESOURCE=$debugTestbedResource DEBUG_TESTBED=$debugTestbed DEBUG_LINK_RXTX=$debugLinkRXTX DEBUG_F_CLEARTIME=$debugFCleartime DEBUG_SF_CLEARTIME=$debugSFCleartime DEBUG_DUP=$debugDup DEBUG_F_SCHED=$debugFSched" 


testSettings="QUEUE_THRESHOLD=$queueThreshold TEST_IPI=$ipi CX_ADAPTIVE_SR=0 RF1A_FEC_ENABLED=$fecEnabled FEC_HAMMING74=$fecHamming74"
miscSettings="ENABLE_SKEW_CORRECTION=0 TEST_DESC=$testDesc"

commonOptions="$scheduleOptions $phyOptions $memoryOptions $loggingOptions $debugOptions $testSettings $miscSettings"
set -x 
if [ "$nonrootRx" != "" ]
then
  for id in $nonrootRx
  do
    make bacon2 install,$id bsl,ref,JH00030$id \
      TDMA_ROOT=0 IS_SENDER=0 \
      DEBUG_AODV_STATE=$rxAodvState \
      $commonOptions DEBUG_TESTBED=1
  done
fi

if [ "$nonrootTx" != "" ]
then
  for id in $nonrootTx
  do
    make bacon2 install,$id bsl,ref,JH00030$id \
      TDMA_ROOT=0 IS_SENDER=1 \
      TEST_DEST_ADDR=$leafDest \
      TEST_REQUEST_ACK=$testRequestAck\
      DEBUG_AODV_STATE=$txAodvState $commonOptions\
      DEBUG_TMP=1 DEBUG_TESTBED=1
  done
fi

if [ "$rootId" != "" ]
then
  make bacon2 install,0 bsl,ref,JH00030$rootId \
    TDMA_ROOT=1 IS_SENDER=$rootSender \
    TEST_DEST_ADDR=$rootDest\
    TEST_REQUEST_ACK=$testRequestAck\
    $commonOptions\
    DEBUG_TMP=1 DEBUG_TESTBED=1 DEBUG_PFS_FREAKOUT=1
fi
