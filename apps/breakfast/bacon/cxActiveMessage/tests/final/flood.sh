#!/bin/bash
bw=0
sel=0
thresh=-100
targetIpi=61440
rateOptions="targetIpi ${targetIpi}UL queueThreshold 10"
floodOptions="senderDest 65535UL requestAck 0"
senderMap=map.nonroot

if [ $# -lt 3 ]
then
  echo "Usage: $0 testDuration txp testNum"
  exit 1
fi
testDuration=$1
txp=$2
testNum=$3

./installTestbed.sh \
  testLabel type.flood.bw.${bw}.sel.${sel}.txp.${txp}.ipi.${targetIpi}.thresh.${thresh}.sm.${senderMap}.tn.${testNum}\
  txp $txp \
  receiverMap map.none \
  senderMap ${senderMap} \
  rootMap map.0 \
  maxDepth 8 \
  fps 40 \
  rssiThreshold $thresh\
  $rateOptions \
  $floodOptions
sleep $testDuration
