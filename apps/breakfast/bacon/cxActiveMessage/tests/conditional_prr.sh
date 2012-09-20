#!/bin/bash
set -x
conditionalPrrOptions="forceSlots 2 maxDepth 2 fps 5 staticScheduler 1 rootTxp 0xC3 leafTxp 0x8D"
shortDuration=$((60*60))
longDuration=$((2 *60 *60))
floodOptions="senderDest 65535UL requestAck 0"
burstOptions="senderDest 0 requestAck 0"
lowRateOptions='targetIpi 143360UL queueThreshold 10'
midRateOptions='targetIpi 61440UL queueThreshold 10'
highRateOptions='targetIpi 1024UL queueThreshold 10'

./installTestbed.sh testLabel conditionalPrr \
  receiverMap map.onehop \
  snifferMap map.twoplushop \
  rootMap map.0 \
  $conditionalPrrOptions
sleep $shortDuration


txp=0x8D
numTransmits=1
for rate in low
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
  #flood
  ./installTestbed.sh testLabel f.${txp}.${numTransmits}.$rate \
    txp $txp \
    senderMap map.nonroot \
    receiverMap map.none \
    rootMap map.0 \
    numTransmits $numTransmits\
    $floodOptions\
    $rateOptions
  sleep $testDuration


  # 2 
  #single sender (burst/flood)
  for sender in 20 40
  do
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
      $floodOptions \
      $rateOptions
    sleep $testDuration
  done
done
