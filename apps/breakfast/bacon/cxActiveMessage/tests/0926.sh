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

    for bufferWidth in 2
    do
      for numTransmits in 1
      do
        for txp in 0x8D
        do
          for rssiThreshold in -90 -80 
          do
            # 1 flood
            #flood: does adding threshold improve distance stability?
            ./installTestbed.sh \
              testLabel lpf.${txp}.${numTransmits}.$rate.$rssiThreshold \
              txp $txp \
              senderMap map.nonroot \
              receiverMap map.none \
              rootMap map.0 \
              numTransmits $numTransmits\
              bufferWidth $bufferWidth\
              $floodOptions\
              rssiThreshold $rssiThreshold \
              $rateOptions
            sleep $testDuration
          done
        done
      done
    done

    #for txp in 0x8D 0x25 0x2D 
    for txp in 0x8D 
    do
      #15 maps
      for map in map.200.capVSenders.* map.200nocap.* map.200.capOnly
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

