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
#OK
#eos=0x2b00
#OK
#eos=0x2b80
#overflow
#eos=0x2bb0
#OK
eos=0x2b98
#overflows
#eos=0x2ba4
#overflows
#eos=0x2b9e

./burn only_0 DEBUG_SCALE=3UL TA_DIV=1UL TDMA_ROOT=1 \
  TDMA_MAX_DEPTH=${md}UL TDMA_MAX_NODES=$maxNodes \
  PATABLE0_SETTING=$txp TDMA_INIT_SYMBOLRATE=$initSR \
  DISCONNECTED_SR=500 TDMA_MAX_RETRANSMIT=${mr}UL \
  CX_ADAPTIVE_SR=0 FLOOD_TEST=0\
  DEBUG_F_STATE=0 DEBUG_SF_STATE=0 DEBUG_AODV_STATE=0\
  DEBUG_F_TESTBED=0 CX_RADIO_LOGGING=$rl DEBUG_RADIO_STATS=$rs \
  END_OF_STACK_ADDR=$eos
