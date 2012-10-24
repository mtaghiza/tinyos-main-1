#!/bin/bash

#re-run 0x8D burst/flood/single tests
shortDuration=$((60*60))
longDuration=$((2 *60 *60))
floodOptions="senderDest 65535UL requestAck 0"
burstOptions="senderDest 0 requestAck 0"
lowRateOptions='targetIpi 143360UL queueThreshold 10'
midRateOptions='targetIpi 61440UL queueThreshold 10'
highRateOptions='targetIpi 1024UL queueThreshold 10'

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
    # 3 x 7 x 15min = 210 min ~6 hours
    #3 tx powers
    for txp in 0x25 0x2D 0x8D
    do
      #7 maps
      for map in map.200.capVSenders.*
      do
        ./installTestbed.sh \
          testLabel $map \
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
    
    # 2 x (1+3) = 8 hours
    for txp in 0x8D
    do
      # 2 thresholds
      for rssiThreshold in -80 -70
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

        #fwd selection: does (maybe) improved distance stability
        # improve performance?
        for bufferWidth in 2
        do
          for cxRoutingTableEntries in 70
          do
            #3 selection methods
            for cxForwarderSelection in 2 0 1
            do
              ./installTestbed.sh \
                testLabel lpb.${txp}.${bufferWidth}.$rate.$cxForwarderSelection.$cxRoutingTableEntries.${rssiThreshold} \
                txp $txp \
                senderMap map.nonroot \
                receiverMap map.none \
                rootMap map.0 \
                numTransmits 1\
                bufferWidth $bufferWidth\
                $burstOptions\
                $rateOptions \
                cxForwarderSelection $cxForwarderSelection \
                rssiThreshold $rssiThreshold \
                cxRoutingTableEntries $cxRoutingTableEntries
              sleep $testDuration
            done
          done
        done
      done
    done
  done
done
