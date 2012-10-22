#!/bin/bash
thresh=-100
senderMap=map.none

if [ $# -lt 3 ]
then
  echo "Usage: $0 testDuration txp testNum"
  exit 1
fi
testDuration=$1
txp=$2
testNum=$3

#idle baseline: 1 setup
./installTestbed.sh \
  testLabel
  type.idle.bw.0.sel.0.txp.${txp}.ipi.0.thresh.${thresh}.sm.${senderMap}.tn.${testNum}\
  txp $txp \
  senderMap ${senderMap} \
  receiverMap map.nonroot \
  rootMap map.0 \
  maxDepth 8 \
  fps 40 \
  rssiThreshold $thresh
sleep $testDuration
