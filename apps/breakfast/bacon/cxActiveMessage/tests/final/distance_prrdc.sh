#!/bin/bash
# txp=0x8D
# thresh=-100
# targetIpi=61440
# rateOptions="targetIpi ${targetIpi}UL queueThreshold 10"
# burstOptions="senderDest 0UL requestAck 0"
# 
# if [ $# -lt 2 ]
# then
#   echo "Usage: $0 testDuration testNum"
#   exit 1
# fi
# testDuration=$1
# testNum=$2
# 
# for bw in 2
# do
#   for sel in 2
#   do
#     for senderMap in map.nonroot
#     do
#       ./installTestbed.sh \
#         testLabel type.burst.bw.${bw}.sel.${sel}.txp.${txp}.ipi.${targetIpi}.thresh.${thresh}.sm.${senderMap}.tn.${testNum}\
#         txp $txp \
#         receiverMap map.nonroot \
#         senderMap $senderMap\
#         rootMap map.0 \
#         maxDepth 8 \
#         fps 40 \
#         rssiThreshold $thresh\
#         $burstOptions\
#         $rateOptions \
#         cxForwarderSelection $sel \
#         bufferWidth $bw
#       sleep $testDuration
#     done
#   done
# done

