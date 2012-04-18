#!/bin/bash
txp=0xC3
maxNodes=50
rl=0
rs=0
initSR=100
mr=1
md=10
#printfs on
#overflow
#eos=0x2b00
#OK
#eos=0x2af8

#printfs off
#end of .bss: 0x2736
#overflow
#eos=0x2bb0
#OK
#stack protection
sp=0
#pool size
ps=3
debugPacket=0

./burn only_0 stackguard DEBUG_SCALE=3UL TA_DIV=1UL TDMA_ROOT=1 \
  TDMA_MAX_DEPTH=${md}UL TDMA_MAX_NODES=$maxNodes \
  PATABLE0_SETTING=$txp TDMA_INIT_SYMBOLRATE=$initSR \
  DISCONNECTED_SR=500 TDMA_MAX_RETRANSMIT=${mr}UL \
  CX_ADAPTIVE_SR=0 FLOOD_TEST=0\
  DEBUG_F_STATE=0 DEBUG_SF_STATE=0 DEBUG_AODV_STATE=0\
  DEBUG_F_TESTBED=0 CX_RADIO_LOGGING=$rl DEBUG_RADIO_STATS=$rs\
  STACK_PROTECTION=$sp CX_MESSAGE_POOL_SIZE=$ps \
  DEBUG_PACKET=$debugPacket
