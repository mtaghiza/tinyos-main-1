#!/bin/bash
txp=0x8D
thresh=-100
targetIpi=1024
rateOptions="targetIpi ${targetIpi}UL queueThreshold 10 txStartDelay 307200UL"
burstOptions="senderDest 0UL requestAck 0"

if [ $# -lt 3 ]
then
  echo "Usage: $0 testDuration txp testNum"
  exit 1
fi
testDuration=$1
txp=$2
testNum=$3

for bw in 2
do
  for sel in 2
  do
    for senderMap in map.nonroot
    do
      ./installTestbed.sh \
        testLabel type.burst.bw.${bw}.sel.${sel}.txp.${txp}.ipi.${targetIpi}.thresh.${thresh}.sm.${senderMap}.tn.${testNum}\
        txp $txp \
        receiverMap map.nonroot \
        senderMap $senderMap\
        rootMap map.0 \
        maxDepth 8 \
        fps 40 \
        rssiThreshold $thresh\
        $burstOptions\
        $rateOptions \
        cxForwarderSelection $sel \
        bufferWidth $bw
      sleep $testDuration
    done
  done
done

