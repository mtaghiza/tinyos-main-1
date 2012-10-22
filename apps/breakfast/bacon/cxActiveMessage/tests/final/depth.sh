#!/bin/bash
thresh=-100
targetIpi=61440
rateOptions="targetIpi ${targetIpi}UL queueThreshold 10"
burstOptions="senderDest 0UL requestAck 0"
senderMap=map.none
bw=0
sel=0

if [ $# -lt 3 ]
then
  echo "Usage: $0 testDuration txp testNum"
  exit 1
fi
testDuration=$1
txp=$2
testNum=$3

./installTestbed.sh \
  testLabel type.rootFlood.bw.${bw}.sel.${sel}.txp.${txp}.ipi.${targetIpi}.thresh.$thresh.sm.${senderMap}.tn.${testNum} \
  txp $txp \
  receiverMap map.nonroot \
  senderMap ${senderMap} \
  senderDest 0\
  rootMap map.0 \
  maxDepth 8 \
  fps 20 \
  forceSlots 5\
  rssiThreshold $thresh
sleep $testDuration
