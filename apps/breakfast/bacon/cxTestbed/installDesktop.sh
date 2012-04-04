#!/bin/bash
txp=0x2D
floodTest=1
tc=64
rootId="0"
nonrootRx=""
nonrootTx="1 2 3 4 5 6"
rl=0
rs=0
mr=1
sr=100
dfs=0
dsfs=0
das=0
dt=0

maxNodes=50
md=10

killall picocom

pushd .
cd ~/tinyos-2.x/apps/Blink
make bacon2
for id in $nonrootRx $nonrootTx $rootId
do
  make bacon2 reinstall bsl,ref,JH00030$id
done
popd

for id in $nonrootRx
do
  make bacon2 install,$id bsl,ref,JH00030$id DEBUG_SCALE=3UL \
    TEST_CHANNEL=$tc TA_DIV=1UL TDMA_ROOT=0 PATABLE0_SETTING=$txp \
    TDMA_INIT_SYMBOLRATE=$sr DISCONNECTED_SR=500 \
    ENABLE_SKEW_CORRECTION=0 FLOOD_TEST=$floodTest IS_SENDER=0\
    DESKTOP_TEST=1 CX_RADIO_LOGGING=$rl \
    DEBUG_F_STATE=$dfs DEBUG_SF_STATE=$dsfs DEBUG_AODV_STATE=$das \
    DEBUG_F_TESTBED=$dt CX_RADIO_LOGGING=$rl DEBUG_RADIO_STATS=$rs
done

for id in $nonrootTx
do
  make bacon2 install,$id bsl,ref,JH00030$id DEBUG_SCALE=3UL \
    TEST_CHANNEL=$tc TA_DIV=1UL TDMA_ROOT=0 PATABLE0_SETTING=$txp \
    TDMA_INIT_SYMBOLRATE=$sr DISCONNECTED_SR=500 \
    ENABLE_SKEW_CORRECTION=0 FLOOD_TEST=$floodTest IS_SENDER=1\
    DESKTOP_TEST=1 CX_RADIO_LOGGING=$rl \
    DEBUG_F_STATE=$dfs DEBUG_SF_STATE=$dsfs DEBUG_AODV_STATE=$das \
    DEBUG_F_TESTBED=$dt CX_RADIO_LOGGING=$rl DEBUG_RADIO_STATS=$rs
done

make bacon2 install,0 bsl,ref,JH00030$rootId DEBUG_SCALE=3UL \
  TEST_CHANNEL=$tc TA_DIV=1UL TDMA_ROOT=1 TDMA_MAX_DEPTH=${md}UL\
  TDMA_MAX_NODES=$maxNodes \
  PATABLE0_SETTING=$txp TDMA_INIT_SYMBOLRATE=$sr DISCONNECTED_SR=500 \
  TDMA_MAX_RETRANSMIT=${mr}UL CX_ADAPTIVE_SR=0 FLOOD_TEST=0\
  DESKTOP_TEST=1 CX_RADIO_LOGGING=$rl \
  DEBUG_F_STATE=$dfs DEBUG_SF_STATE=$dsfs DEBUG_AODV_STATE=$das \
  DEBUG_F_TESTBED=$dt CX_RADIO_LOGGING=$rl DEBUG_RADIO_STATS=$rs
