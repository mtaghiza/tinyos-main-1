#!/bin/bash
set -x 
txp=0xC3
debugScale=4UL
#radio logging/stats reporting
rl=0
rs=0

#initial symbol rate
initSR=250

#memory params
#stack protection
sp=1
#size of pool for messages
ps=3

#debug flags
#print slot violations
sv=0
#report CRC failures
crc=1
#debugging messages for pre-routed transmissions, scoped-flood
# routing, aodv state info, aodv clear time debug
pr=0
sfr=0
txAodvState=0
rxAodvState=0
aodvClear=0
#debug RXREADY error messages
rxr=0

#test parameters
#flood=1, scoped-flood=0
floodTest=1
#packet generation interval
#ipi=61440UL
ipi=5120UL
#how many packets to send in a burst
queueThreshold=2

./burn map.nonroot.rx DEBUG_SCALE=$debugScale TA_DIV=1UL TDMA_ROOT=0 \
  PATABLE0_SETTING=$txp TDMA_INIT_SYMBOLRATE=$initSR DISCONNECTED_SR=500 \
  ENABLE_SKEW_CORRECTION=0 FLOOD_TEST=$floodTest IS_SENDER=0 \
  DEBUG_F_STATE=0 DEBUG_SF_STATE=0 DEBUG_AODV_STATE=$rxAodvState \
  DEBUG_F_TESTBED=0 CX_RADIO_LOGGING=$rl DEBUG_RADIO_STATS=$rs \
  STACK_PROTECTION=$sp CX_MESSAGE_POOL_SIZE=$ps \
  DEBUG_SF_SV=$sv DEBUG_F_SV=$sv DEBUG_SF_TESTBED_PR=$pr \
  DEBUG_SF_ROUTE=$sfr DEBUG_TESTBED_CRC=$crc \
  DEBUG_AODV_CLEAR=$aodvClear DEBUG_TEST_QUEUE=1\
  DEBUG_RXREADY_ERROR=$rxr
./burn map.nonroot.tx DEBUG_SCALE=$debugScale TA_DIV=1UL TDMA_ROOT=0 \
  PATABLE0_SETTING=$txp TDMA_INIT_SYMBOLRATE=$initSR DISCONNECTED_SR=500 \
  ENABLE_SKEW_CORRECTION=0 FLOOD_TEST=$floodTest IS_SENDER=1 \
  DEBUG_F_STATE=0 DEBUG_SF_STATE=0 DEBUG_AODV_STATE=$txAodvState \
  DEBUG_F_TESTBED=0 CX_RADIO_LOGGING=$rl DEBUG_RADIO_STATS=$rs \
  STACK_PROTECTION=$sp CX_MESSAGE_POOL_SIZE=$ps \
  DEBUG_SF_SV=$sv DEBUG_F_SV=$sv DEBUG_SF_TESTBED_PR=$pr \
  DEBUG_SF_ROUTE=$sfr DEBUG_TESTBED_CRC=$crc \
  DEBUG_AODV_CLEAR=$aodvClear DEBUG_TEST_QUEUE=1 \
  QUEUE_THRESHOLD=$queueThreshold TEST_IPI=$ipi\
  DEBUG_RXREADY_ERROR=$rxr
