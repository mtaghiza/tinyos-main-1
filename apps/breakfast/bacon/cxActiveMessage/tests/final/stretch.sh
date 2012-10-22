#!/bin/bash
thresh=-100
targetIpi=61440
rateOptions="targetIpi ${targetIpi}UL queueThreshold 10"
burstOptions="senderDest 0UL requestAck 0"
floodOptions="senderDest 65535UL requestAck 0"
senderMap=map.nonroot

if [ $# -lt 2 ]
then
  echo "Usage: $0 testDuration testNum"
  exit 1
fi
testDuration=$1
testNum=$2

for txp in 0x8D
do
  for bw in 0
  do
    for sel in 2
    do
      ./installTestbed.sh \
        testLabel type.burst.bw.${bw}.sel.${sel}.txp.${txp}.ipi.${targetIpi}.thresh.${thresh}.sm.${senderMap}.tn.${testNum}\
        txp $txp \
        receiverMap map.none \
        senderMap $senderMap \
        rootMap map.0 \
        maxDepth 8 \
        fps 40 \
        rssiThreshold $thresh\
        $burstOptions\
        cxForwarderSelection $sel \
        $rateOptions\
        bufferWidth $bw
      sleep $testDuration
    done
  done
done

for txp in 0x25 0x2D 
do
  for bw in 0
  do
    for sel in 0
    do
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
    done
  done
done


for txp in 0x25 0x2D
do
  for bw in 2
  do
    for sel in 2
    do
      ./installTestbed.sh \
        testLabel type.burst.bw.${bw}.sel.${sel}.txp.${txp}.ipi.${targetIpi}.thresh.${thresh}.sm.${senderMap}.tn.${testNum}\
        txp $txp \
        receiverMap map.none \
        senderMap $senderMap \
        rootMap map.0 \
        maxDepth 8 \
        fps 40 \
        rssiThreshold $thresh\
        $burstOptions\
        cxForwarderSelection $sel \
        $rateOptions\
        bufferWidth $bw
      sleep $testDuration
    done
  done
done


