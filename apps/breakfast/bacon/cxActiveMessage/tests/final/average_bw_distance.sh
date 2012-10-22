#!/bin/bash
thresh=-100
targetIpi=61440
rateOptions="targetIpi ${targetIpi}UL queueThreshold 10"
burstOptions="senderDest 0UL requestAck 0"
senderMap=map.nonroot

if [ $# -lt 2 ]
then
  echo "Usage: $0 testDuration testNum"
  exit 1
fi
testDuration=$1
testNum=$2

#boundary width
for txp in 0x2D
do
  for bw in 1 3 5
  do
    for sel in 1
    do
      for roundThresh in 8
      do
        ./installTestbed.sh \
          testLabel type.burst.bw.${bw}.sel.${sel}.txp.${txp}.ipi.${targetIpi}.thresh.${thresh}.sm.${senderMap}.rt.${roundThresh}.tn.${testNum}\
          txp $txp \
          receiverMap map.none \
          senderMap $senderMap \
          rootMap map.0 \
          maxDepth 8 \
          fps 40 \
          rssiThreshold $thresh\
          $burstOptions\
          cxForwarderSelection $sel \
          $rateOptions \
          bufferWidth $bw \
          roundThresh $roundThresh
        sleep $testDuration
      done
    done
  done
done

for txp in 0x25 0x8D
do
  for bw in 2
  do
    for sel in 1
    do
      for roundThresh in 8
      do
        ./installTestbed.sh \
          testLabel type.burst.bw.${bw}.sel.${sel}.txp.${txp}.ipi.${targetIpi}.thresh.${thresh}.sm.${senderMap}.rt.${roundThresh}.tn.${testNum}\
          txp $txp \
          receiverMap map.none \
          senderMap $senderMap \
          rootMap map.0 \
          maxDepth 8 \
          fps 40 \
          rssiThreshold $thresh\
          $burstOptions\
          cxForwarderSelection $sel \
          $rateOptions \
          bufferWidth $bw \
          roundThresh $roundThresh
        sleep $testDuration
      done
    done
  done
done
