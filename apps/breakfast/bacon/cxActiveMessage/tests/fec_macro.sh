#!/bin/bash
shortDuration=$((60*60))
longDuration=$((2 *60 *60))

txp=0x8D
i=0
midRateOptions='targetIpi 61440UL queueThreshold 10'
burstOptions="senderDest 0 requestAck 0"
floodOptions="senderDest 65535UL requestAck 0"


#16 total test setups
# 1 idle (should be shorter, probably)
# 1 flood
# 3 selection method
# 4 buffer width
# 3 throughput v. distance
# 3 duty cycle contribution v. distance
while [ true ]
do
  i=$(( $i + 1))
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
    
    #idle baseline: 1 setup
    for cxForwarderSelection in na
    do
      for thresh in -100
      do
        for fec in 1
        do
          for bufferWidth in 0
          do
            for senderMap in map.none
            do
              #TODO: use flood options
            done
          done
        done
    done

    #flood baseline: 1 setup
    for cxForwarderSelection in na
    do
      for thresh in -100
      do
        for fec in 1
        do
          for bufferWidth in 0
          do
            for senderMap in map.nonroot
            do
              #TODO: use flood options
            done
          done
        done
    done

    #vary selection method: 3 setups
    for cxForwarderSelection in 2 1 0
    do
      for thresh in -100
      do
        for fec in 1
        do
          for bufferWidth in 0
          do
            for senderMap in map.nonroot
            do
              #TODO: use burst options
            done
          done
        done
      done
    done

    #vary buffer width: 5 setups
    for cxForwarderSelection in 2
    do
      for thresh in -100
      do
        for fec in 1
        do
          for bufferWidth in 0 1 2 3 5
          do
            for senderMap in map.nonroot
            do
              #TODO: use burst options
            done
          done
        done
      done
    done

    #vary sender distance: 6 setups
    for cxForwarderSelection in 2
    do
      for thresh in -100
      do
        for fec in 1
        do
          for bufferWidth in 2
          do
            for senderMap in map.close map.mid map.far
            do
              #throughput improvement v. distance
              rateOptions=$highRateOptions
              #TODO: use burst options
              
              #duty cycle contribution v. distance
              rateOptions=$midRateOptions
              #TODO: use burst options
            done
          done
        done
      done
    done
  done
done

