#!/bin/bash
testDuration=$((60*60))
floodOptions="senderDest 65535UL requestAck 0"
burstOptions="senderDest 0 requestAck 0"

for txp in 0x8D 
do
  #burst with buffer zone
  for bufferWidth in 0 1 3 5 7
  do
    numTransmits=1
    ./installTestbed.sh testLabel lpb.${txp}.${numTransmits}.${bufferWidth} \
      txp $txp \
      senderMap map.nonroot \
      receiverMap map.none \
      rootMap map.0 \
      numTransmits $numTransmits\
      bufferWidth $bufferWidth\
      $burstOptions
    sleep $testDuration
  done
  #burst w. retx
  for numTransmits in 2
  do
    for bufferWidth in 0 1
    do
      ./installTestbed.sh testLabel lpb.${txp}.${numTransmits}.${bufferWidth} \
        txp $txp \
        senderMap map.nonroot \
        receiverMap map.none \
        rootMap map.0 \
        numTransmits $numTransmits\
        bufferWidth $bufferWidth\
        $burstOptions
      sleep $testDuration
    done
  done
done

for sender in 20 40
do
  for txp in 0x8d 
  do
    ./installTestbed.sh testLabel single.b.${txp}.${sender} \
      txp $txp \
      senderMap map.${sender} \
      receiverMap map.nonroot \
      $burstOptions
    sleep $testDuration
    ./installTestbed.sh testLabel single.f.${txp}.${sender}\
      txp $txp \
      senderMap map.${sender} \
      receiverMap map.nonroot \
      $floodOptions
    sleep $testDuration
  done
done
