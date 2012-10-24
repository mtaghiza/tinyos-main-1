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

    #up to 7 senders, random selection
    map=map.200nocap
    ./installTestbed.sh \
        testLabel random.$map \
        rootTxp 0xC3 leafTxp 0x8D \
        receiverMap $map \
        senderMap map.none \
        rootMap map.0 \
        maxDepth 2 \
        fps 10 \
        forceSlots 5 \
        snifferMap map.1\
        fwdDropRate 0x80
    sleep $((2 * 60 * 60))
    
    #add senders one at a time (weakest first)
    for map in map.200nocap.*
    do
      ./installTestbed.sh \
        testLabel deterministic.$map \
        rootTxp 0xC3 leafTxp 0x8D \
        receiverMap $map \
        senderMap map.none \
        rootMap map.0 \
        maxDepth 2 \
        fps 10 \
        forceSlots 5 \
        snifferMap map.1
      sleep $((10 * 60 ))
    done

    for txp in 0x8D 
    do
      #3 x 6  = 18
      for numTransmits in 1
      do
        #burst with buffer zone = 2
        for bufferWidth in 2
        do
          # test with small table (local only) and full table
          for cxRoutingTableEntries in 70 3
          do
            for cxForwarderSelection in 2 0 1
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

      #2 transmits, no buffer
      for numTransmits in 2
      do
        for bufferWidth in 0
        do
          for cxForwarderSelection in 2 0 1
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
    done
  
  done 
done

