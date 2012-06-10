#!/bin/bash
#radio physical params
txp=0x25
tc=0

debugScale=4UL

#test setup
floodTest=0
rootId="0"
nonrootRx=""
#allPlugged="0 1 2 3"
allPlugged="0 1"
nonrootTx="1"

fecEnabled=0
fecHamming74=1

ipi=5120UL
queueThreshold=1

#network params
numSlots=10
fps=10
md=2
mr=1

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
#debug RXREADY error messages
rxr=0

killall picocom

pushd .
cd ~/tinyos-2.x/apps/Blink
make bacon2
for id in $allPlugged
do
  make bacon2 reinstall bsl,ref,JH00030$id
done
popd

scheduleOptions="DEBUG_SCALE=$debugScale TA_DIV=1UL SCHED_INIT_SYMBOLRATE=$initSR DISCONNECTED_SR=500 SCHED_MAX_DEPTH=${md}UL SCHED_FRAMES_PER_SLOT=$fps SCHED_NUM_SLOTS=$numSlots SCHED_MAX_RETRANSMIT=${mr}UL"

phyOptions="PATABLE0_SETTING=$txp TEST_CHANNEL=$tc"

memoryOptions="STACK_PROTECTION=$sp CX_MESSAGE_POOL_SIZE=$ps"

loggingOptions="CX_RADIO_LOGGING=$rl DEBUG_RADIO_STATS=$rs"

debugOptions="DEBUG_F_STATE=0 DEBUG_SF_STATE=0  DEBUG_F_TESTBED=0 DEBUG_SF_SV=$sv DEBUG_F_SV=$sv DEBUG_SF_TESTBED_PR=$pr DEBUG_SF_ROUTE=$sfr DEBUG_TESTBED_CRC=$crc DEBUG_AODV_CLEAR=$aodvClear DEBUG_TEST_QUEUE=1 DEBUG_RXREADY_ERROR=$rxr DEBUG_PACKET=$debugPacket DEBUG_CONFIG=$debugConfig DEBUG_TDMA_SS=$debugSS DEBUG_FEC=$debugFEC DEBUG_SF_RX=$debugSFRX" 


testSettings="FLOOD_TEST=$floodTest QUEUE_THRESHOLD=$queueThreshold
TEST_IPI=$ipi CX_ADAPTIVE_SR=0 RF1A_FEC_ENABLED=$fecEnabled FEC_HAMMING74=$fecHamming74"
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
      DEBUG_AODV_STATE=$txAodvState $commonOptions\
      DEBUG_TMP=1
  done
fi

if [ "$rootId" != "" ]
then
  make bacon2 install,0 bsl,ref,JH00030$rootId \
    TDMA_ROOT=1 $commonOptions\
    DEBUG_TMP=1
fi
