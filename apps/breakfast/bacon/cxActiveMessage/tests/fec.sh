#!/bin/bash
testDuration=$((30*60))
txp=0x8D
i=0
while [ true ]
do
  i=$(( $i + 1))
  for thresh in -90 -100
  do
    for fec in 1 0
    do
      ./installTestbed.sh \
        testLabel flood.thresh.$thresh.fec.${fec}.$i \
        txp $txp \
        receiverMap map.nonroot \
        senderMap map.1\
        senderDest 0\
        rootMap map.0 \
        maxDepth 10 \
        fps 20 \
        forceSlots 5\
        rssiThreshold $thresh\
        fecEnabled $fec
      sleep $testDuration
    done
  done
done
