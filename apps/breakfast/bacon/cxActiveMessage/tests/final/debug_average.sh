#!/bin/bash
thresh=-100
targetIpi=61440
rateOptions="targetIpi ${targetIpi}UL queueThreshold 10"
burstOptions="senderDest 0UL requestAck 0"
senderMap=map.none
bw=0

if [ $# -lt 1 ]
then
  echo "Usage: $0 roundThresh"
  exit 1
fi
txp=0x2D
roundThresh=$1

./installTestbed.sh \
  testLabel type.debug.roundThresh.$roundThresh \
  txp $txp \
  receiverMap map.nonroot \
  senderMap ${senderMap} \
  senderDest 0\
  rootMap map.0 \
  maxDepth 8 \
  fps 20 \
  forceSlots 5\
  rssiThreshold $thresh\
  cxForwarderSelection 1\
  roundThresh $roundThresh
