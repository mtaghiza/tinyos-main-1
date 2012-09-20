#!/bin/bash

#re-run 0x8D burst/flood/single tests
shortDuration=$((60*60))
longDuration=$((2 *60 *60))
floodOptions="senderDest 65535UL requestAck 0"
burstOptions="senderDest 0 requestAck 0"
lowRateOptions='targetIpi 143360UL queueThreshold 10'
midRateOptions='targetIpi 61440UL queueThreshold 10'
highRateOptions='targetIpi 1024UL queueThreshold 10'

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
    #3 x 6  = 18
    for numTransmits in 1
    do
      #burst with buffer zone
      for bufferWidth in 0 1 3
      do
        for cxForwarderSelection in 1 2 
        do
          for cxRoutingTableEntries in 3 70
          do
            ./installTestbed.sh \
              testLabel lpb.${txp}.${numTransmits}.${bufferWidth}.$rate.$cxForwarderSelection.$cxRoutingTableEntries \
              txp $txp \
              senderMap map.nonroot \
              receiverMap map.none \
              rootMap map.0 \
              numTransmits $numTransmits\
              bufferWidth $bufferWidth\
              $burstOptions\
              $rateOptions \
              cxForwarderSelection $cxForwarderSelection \
              cxRoutingTableEntries $cxRoutingTableEntries
            sleep $testDuration
          done
        done
      done
      #flood
      ./installTestbed.sh testLabel lpf.${txp}.${numTransmits}.$rate \
        txp $txp \
        senderMap map.nonroot \
        receiverMap map.none \
        rootMap map.0 \
        numTransmits $numTransmits\
        bufferWidth $bufferWidth\
        $floodOptions\
        $rateOptions
      sleep $testDuration
    done
  done

done 
