#!/bin/bash

autoRun=0

#radio physical params
txp=0xC3
tc=0

debugScale=4

#test setup
floodTest=1
root=map.root
nonrootRx=map.nonroot.rx
#allPlugged="0 1 2 3"
#allPlugged="0 1 2"
nonrootTx=map.nonroot.tx

fecEnabled=0
fecHamming74=1

ipi=5120UL
queueThreshold=2

#network/schedule params
fps=20
md=10
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
#debug RXREADY error messages
rxr=1

#bug fix options
waitForPacket=1
synchAtRx=1

programDelay=120

#killall picocom

while [ $# -gt 0 ]
do
  case $1 in
    synchAtRx)
      shift 1
      synchAtRx=$1
      shift 1
    ;;
    waitForPacket)
      shift 1
      waitForPacket=$1
      shift 1
    ;;
    autoRun)
      shift 1
      autoRun=$1
      shift 1
    ;;
    fps)
      shift 1
      fps=$1
      shift 1 
    ;;
    programDelay)
      shift 1
      programDelay=$1
      shift 1
    ;;
    initSR)
      shift 1
      initSR=$1
      shift 1
    ;;
    fecEnabled)
      shift 1
      fecEnabled=$1
      shift 1
    ;;
    nonrootRx)
      shift 1
      nonrootRx=$1
      shift 1
    ;;
    nonrootTx)
      shift 1
      nonrootTx=$1
      shift 1
    ;;
    floodTest)
      shift 1
      floodTest=$1
      shift 1
    ;;
    debugScale)
      shift 1
      debugScale=$1
      shift 1
    ;;
    *)
      echo "unrecognized: $1"
      shift 1
    ;;
  esac
done

maxNodes=$(grep -v '#' $root $nonrootRx $nonrootTx | awk '{print $NF}' | sort -n | tail -1)
numSlots=$(($maxNodes + 5))

scheduleOptions="DEBUG_SCALE=$debugScale TA_DIV=1UL SCHED_INIT_SYMBOLRATE=$initSR DISCONNECTED_SR=500 SCHED_MAX_DEPTH=${md}UL SCHED_FRAMES_PER_SLOT=$fps SCHED_NUM_SLOTS=$numSlots SCHED_MAX_RETRANSMIT=${mr}UL"

phyOptions="PATABLE0_SETTING=$txp TEST_CHANNEL=$tc"

memoryOptions="STACK_PROTECTION=$sp CX_MESSAGE_POOL_SIZE=$ps"

loggingOptions="CX_RADIO_LOGGING=$rl DEBUG_RADIO_STATS=$rs"

debugOptions="DEBUG_F_STATE=0 DEBUG_SF_STATE=0  DEBUG_F_TESTBED=0 DEBUG_SF_SV=$sv DEBUG_F_SV=$sv DEBUG_SF_TESTBED_PR=$pr DEBUG_SF_ROUTE=$sfr DEBUG_TESTBED_CRC=$crc DEBUG_AODV_CLEAR=$aodvClear DEBUG_TEST_QUEUE=1 DEBUG_RXREADY_ERROR=$rxr DEBUG_PACKET=$debugPacket DEBUG_CONFIG=$debugConfig DEBUG_TDMA_SS=0 DEBUG_FEC=$debugFEC DEBUG_TESTBED=$debugTestbed" 


testSettings="FLOOD_TEST=$floodTest QUEUE_THRESHOLD=$queueThreshold TEST_IPI=$ipi CX_ADAPTIVE_SR=0 RF1A_FEC_ENABLED=$fecEnabled FEC_HAMMING74=$fecHamming74"
miscSettings="ENABLE_SKEW_CORRECTION=0"
bugFixSettings="SYNCH_AT_RX=$synchAtRx WAIT_FOR_PACKET=$waitForPacket"

commonOptions="$scheduleOptions $phyOptions $memoryOptions $loggingOptions $debugOptions $testSettings $miscSettings $bugFixSettings"

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

echo "START $(date +%s) fec $fecEnabled sr $initSR flood $floodTest rx $nonrootRx tx $nonrootTx" | tee -a tests.log

if [ "$nonrootRx" != "" ]
then
  ./burn $nonrootRx \
      TDMA_ROOT=0 IS_SENDER=0 \
      DEBUG_AODV_STATE=$rxAodvState $commonOptions
fi

if [ "$nonrootTx" != "" ]
then
  ./burn $nonrootTx \
      TDMA_ROOT=0 IS_SENDER=1 \
      DEBUG_AODV_STATE=$txAodvState $commonOptions 
fi

if [ "$root" != "" ]
then
  ./burn $root \
    TDMA_ROOT=1 $commonOptions
fi
