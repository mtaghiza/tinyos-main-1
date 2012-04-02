#!/bin/bash
killall picocom
topo=1
useTopo=1
nonRootRx=""
nonRootTX=""
retx=1
set -x 
make bacon2 install,0 bsl,/dev/ttyUSB0 DEBUG_SCALE=3UL TA_DIV=1UL \
  TDMA_ROOT=1 TDMA_MAX_DEPTH=6UL TDMA_MAX_NODES=6 \
  PATABLE0_SETTING=0x03 TDMA_INIT_SYMBOLRATE=125 \
  DISCONNECTED_SR=500 TDMA_MAX_RETRANSMIT=$retx\
  CX_ADAPTIVE_SR=0 FLOOD_TEST=0 \
  SW_TOPO=$useTopo TOPOLOGY=$topo

for id in $nonRootRx
do
  make bacon2 install,$id bsl,/dev/ttyUSB$id DEBUG_SCALE=3UL \
    TA_DIV=1UL TDMA_ROOT=0 PATABLE0_SETTING=0x03 \
    TDMA_INIT_SYMBOLRATE=125 DISCONNECTED_SR=500 \
    ENABLE_SKEW_CORRECTION=0 FLOOD_TEST=1 IS_SENDER=0 \
    TDMA_MAX_RETRANSMIT=$retx \
    SW_TOPO=1 TOPOLOGY=$topo
  
done

if [ "$nonRootTX" != "" ]
then
  for id in $nonRootTX
  do
    make bacon2 install,$id bsl,/dev/ttyUSB$id DEBUG_SCALE=3UL \
      TA_DIV=1UL TDMA_ROOT=0 PATABLE0_SETTING=0x03 \
      TDMA_INIT_SYMBOLRATE=125 DISCONNECTED_SR=500 \
      ENABLE_SKEW_CORRECTION=0 FLOOD_TEST=1 IS_SENDER=1 \
      SW_TOPO=1 TOPOLOGY=$topo
  done
fi
