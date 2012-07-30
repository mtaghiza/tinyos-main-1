#!/bin/bash
autoRun=0

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
firstIdleSlot=48

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

numNodes=$(cat $root $nonrootRx $nonrootTx | grep -c -v '#' )
numSlots=$(($numNodes + 5))

scheduleOptions="DEBUG_SCALE=$debugScale TA_DIV=1UL SCHED_INIT_SYMBOLRATE=$initSR DISCONNECTED_SR=500 SCHED_MAX_DEPTH=${md}UL SCHED_FRAMES_PER_SLOT=$fps SCHED_NUM_SLOTS=$numSlots SCHED_MAX_RETRANSMIT=${mr}UL STATIC_SCHEDULER=$staticScheduler STATIC_FIRST_IDLE_SLOT=$firstIdleSlot"

phyOptions="PATABLE0_SETTING=$txp TEST_CHANNEL=$tc"

memoryOptions="STACK_PROTECTION=$sp CX_MESSAGE_POOL_SIZE=$ps"

loggingOptions="CX_RADIO_LOGGING=$rl DEBUG_RADIO_STATS=$rs"

debugOptions="DEBUG_F_STATE=0 DEBUG_SF_STATE=0  DEBUG_F_TESTBED=0 DEBUG_SF_SV=$sv DEBUG_F_SV=$sv DEBUG_SF_TESTBED_PR=$pr DEBUG_SF_ROUTE=$sfr DEBUG_TESTBED_CRC=$crc DEBUG_AODV_CLEAR=$aodvClear DEBUG_TEST_QUEUE=1 DEBUG_RXREADY_ERROR=$rxr DEBUG_PACKET=$debugPacket DEBUG_CONFIG=$debugConfig DEBUG_TDMA_SS=$debugSS DEBUG_FEC=$debugFEC DEBUG_SF_RX=$debugSFRX DEBUG_TESTBED_RESOURCE=$debugTestbedResource DEBUG_TESTBED=1" 


testSettings="QUEUE_THRESHOLD=$queueThreshold TEST_IPI=$ipi CX_ADAPTIVE_SR=0 RF1A_FEC_ENABLED=$fecEnabled FEC_HAMMING74=$fecHamming74"
miscSettings="ENABLE_SKEW_CORRECTION=0"

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
