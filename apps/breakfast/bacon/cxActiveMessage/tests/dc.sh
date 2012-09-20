#!/bin/bash

testDuration=$((60*60))
longTestDuration=$((4*60*60))
floodOptions="senderDest 65535UL requestAck 0"
burstOptions="senderDest 0 requestAck 1"
lowRateOptions='targetIpi 143360UL'
for i in $(seq 100 200)
do
  for txp in 0x2d
  do
    ./installTestbed.sh testLabel idle.${txp}.${i}\
      txp $txp \
      senderMap map.none \
      receiverMap map.nonroot \
      rootMap map.0 \
      numTransmits 1
    sleep $testDuration
    for sender in 20 40
    do
      ./installTestbed.sh testLabel single.f.${txp}.${sender}.${i} \
        txp $txp \
        senderMap map.${sender} \
        receiverMap map.nonroot \
        $burstOptions
      sleep $testDuration

      ./installTestbed.sh testLabel single.b.${txp}.${sender}.${i}\
        txp $txp \
        senderMap map.${sender} \
        receiverMap map.nonroot \
        $floodOptions
      sleep $testDuration
    done
  done
  
  numTransmits=1
  bufferWidth=0
  for txp in 0x2d 0x8d
  do
    ./installTestbed.sh testLabel f.low.${txp}.${numTransmits}.${bufferWidth}.${i} \
      txp $txp \
      senderMap map.nonroot \
      receiverMap map.none \
      rootMap map.0 \
      numTransmits $numTransmits\
      $lowRateOptions \
      $floodOptions
    sleep $longTestDuration
    
    #NOTE: cut off during this test
    ./installTestbed.sh testLabel b.low.${txp}.${numTransmits}.${bufferWidth}.${i} \
      txp $txp \
      senderMap map.nonroot \
      receiverMap map.none \
      rootMap map.0 \
      numTransmits $numTransmits\
      bufferWidth $bufferWidth\
      $lowRateOptions \
      $burstOptions
    sleep $longTestDuration
  done
  for txp in 0x8d
  do
    ./installTestbed.sh testLabel idle.${txp}.${i}\
      txp $txp \
      senderMap map.none \
      receiverMap map.nonroot \
      rootMap map.0 \
      numTransmits 1
    sleep $testDuration
    for sender in 20 40
    do
      ./installTestbed.sh testLabel single.f.${txp}.${sender}.${i} \
        txp $txp \
        senderMap map.${sender} \
        receiverMap map.nonroot \
        $burstOptions
      sleep $testDuration

      ./installTestbed.sh testLabel single.b.${txp}.${sender}.${i}\
        txp $txp \
        senderMap map.${sender} \
        receiverMap map.nonroot \
        $floodOptions
      sleep $testDuration
    done
  done
 done
