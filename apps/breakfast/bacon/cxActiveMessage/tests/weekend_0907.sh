#!/bin/bash

#re-run 0x8D burst/flood/single tests
shortDuration=$((60*60))
longDuration=$((2 *60 *60))
floodOptions="senderDest 65535UL requestAck 0"
burstOptions="senderDest 0 requestAck 0"
lowRateOptions='targetIpi 143360UL queueThreshold 10'
midRateOptions='targetIpi 61440UL queueThreshold 10'
highRateOptions='targetIpi 1024UL queueThreshold 10'

for rate in high mid low
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
    for numTransmits in 1 2 3
    do
      #burst with buffer zone
      for bufferWidth in 0 1 3 5 7
      do
        ./installTestbed.sh testLabel lpb.${txp}.${numTransmits}.${bufferWidth}.$rate \
          txp $txp \
          senderMap map.nonroot \
          receiverMap map.none \
          rootMap map.0 \
          numTransmits $numTransmits\
          bufferWidth $bufferWidth\
          $burstOptions\
          $rateOptions
        sleep $testDuration
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
  # 2 
  #single sender (burst/flood)
  for sender in 20 40
  do
    txp=0x8d
    numTransmits=1
    bufferWidth=1
    ./installTestbed.sh testLabel single.b.${txp}.${sender}.$rate \
      txp $txp \
      senderMap map.${sender} \
      receiverMap map.nonroot \
      numTransmits $numTransmits\
      bufferWidth $bufferWidth\
      $burstOptions \
      $rateOptions
    sleep $testDuration

    ./installTestbed.sh testLabel single.f.${txp}.${sender}.$rate\
      txp $txp \
      senderMap map.${sender} \
      receiverMap map.nonroot \
      numTransmits $numTransmits\
      bufferWidth $bufferWidth\
      $floodOptions \
      $rateOptions
    sleep $testDuration
  done
done 
