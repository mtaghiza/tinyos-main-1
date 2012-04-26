#!/bin/bash
#radio physical params
txp=0x8D
tc=0

debugScale=2UL

#test setup
floodTest=1
rootId="0"
nonrootRx="1 2 3"
#nonrootRx=""
nonrootTx=""

ipi=5120UL
queueThreshold=2

#network params
maxNodes=5
fps=5
md=5
mr=1

#radio logging
rl=0
rs=0

#schedule config
#init symbol rate
initSR=100

#stack protection
sp=1
#pool size
ps=3

debugPacket=0
sv=0
pr=0
sfr=0
crc=1
debugConfig=1
txAodvState=0
rxAodvState=0
aodvClear=0
#debug RXREADY error messages
rxr=1

killall picocom

pushd .
cd ~/tinyos-2.x/apps/Blink
make bacon2
for id in $nonrootRx $nonrootTx $rootId
do
  make bacon2 reinstall bsl,ref,JH00030$id
done
popd

scheduleOptions="DEBUG_SCALE=$debugScale TA_DIV=1UL  TDMA_INIT_SYMBOLRATE=$initSR DISCONNECTED_SR=500 TDMA_MAX_DEPTH=${md}UL TDMA_MAX_NODES=$maxNodes TDMA_ROOT_FRAMES_PER_SLOT=$fps TDMA_MAX_RETRANSMIT=${mr}UL"

phyOptions="PATABLE0_SETTING=$txp TEST_CHANNEL=$tc"

memoryOptions="STACK_PROTECTION=$sp CX_MESSAGE_POOL_SIZE=$ps"

loggingOptions="CX_RADIO_LOGGING=$rl DEBUG_RADIO_STATS=$rs"

debugOptions="DEBUG_F_STATE=0 DEBUG_SF_STATE=0  DEBUG_F_TESTBED=0 DEBUG_SF_SV=$sv DEBUG_F_SV=$sv DEBUG_SF_TESTBED_PR=$pr DEBUG_SF_ROUTE=$sfr DEBUG_TESTBED_CRC=$crc DEBUG_AODV_CLEAR=$aodvClear DEBUG_TEST_QUEUE=1 DEBUG_RXREADY_ERROR=$rxr DEBUG_PACKET=$debugPacket DEBUG_CONFIG=$debugConfig DEBUG_TDMA_SS=0" 


testSettings="FLOOD_TEST=$floodTest QUEUE_THRESHOLD=$queueThreshold TEST_IPI=$ipi CX_ADAPTIVE_SR=0"
miscSettings="ENABLE_SKEW_CORRECTION=0"

commonOptions="$scheduleOptions $phyOptions $memoryOptions $loggingOptions $debugOptions $testSettings $miscSettings"
set -x 
if [ "$nonrootRx" != "" ]
then
  for id in $nonrootRx
  do
    make bacon2 install,$id bsl,ref,JH00030$id \
      TDMA_ROOT=0 IS_SENDER=0 \
      DEBUG_AODV_STATE=$rxAodvState $commonOptions
  done
fi

if [ "$nonrootTx" != "" ]
then
  for id in $nonrootTx
  do
    make bacon2 install,$id bsl,ref,JH00030$id \
      TDMA_ROOT=0 IS_SENDER=1 \
      DEBUG_AODV_STATE=$txAodvState $commonOptions
  done
fi

if [ "$rootId" != "" ]
then
  make bacon2 install,0 bsl,ref,JH00030$rootId \
    TDMA_ROOT=1 $commonOptions
fi
