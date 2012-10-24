#!/bin/bash
testDuration=$((30*60))
txp=0x8D
i=0
while [ true ]
do
  i=$(( $i + 1))
  for thresh in -100 -90
  do
    ./installTestbed.sh \
      testLabel flood.thresh.$thresh.$i \
      txp $txp \
      receiverMap map.nonroot \
      senderMap map.none\
      rootMap map.0 \
      maxDepth 10 \
      fps 20 \
      forceSlots 5\
      rssiThreshold $thresh
    sleep $testDuration
  done
done
