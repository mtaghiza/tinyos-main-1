#!/bin/bash

#re-run 0x8D burst/flood/single tests
shortDuration=$((60*60))
longDuration=$((2 *60 *60))
floodOptions="senderDest 65535UL requestAck 0"
burstOptions="senderDest 0 requestAck 0"
lowRateOptions='targetIpi 143360UL queueThreshold 10'
midRateOptions='targetIpi 61440UL queueThreshold 10'
highRateOptions='targetIpi 1024UL queueThreshold 10'

set -x 
while [ true ]
do
  for rate in mid
  do
    if [ "$rate" == "low" ]
    then
      rateOptions=$lowRateOptions
      testDuration=$longDuration
    elif [ "$rate" == "high" ] 
    then
      rateOptions=$highRateOptions
      testDuration=$shortDuration
    elif [ "$rate" == "mid" ]
    then
      rateOptions=$midRateOptions
      testDuration=$shortDuration
    else
      echo "unknown rate $rate"
      exit 1
    fi

    for txp in 0x8D 
    do
      #24 maps: 6 hours 
      #for map in map.200.capVSenders.* map.200nocap.* map.200.capOnly*
      for map in map.200.capVSenders.* map.200nocap.* map.200.capOnly*
      do
        ./installTestbed.sh \
          testLabel $map.$txp \
          rootTxp 0xC3 leafTxp $txp \
          receiverMap $map \
          senderMap map.none \
          rootMap map.0 \
          maxDepth 2 \
          fps 10 \
          forceSlots 5 \
          snifferMap map.1
        sleep $(( 15 * 60 ))
      done
    done
  done
done

