#!/bin/bash
set -x
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

  txp=0x8D 
  bufferWidth=0
  numTransmits=1
  #idle: correct for skew
  ./installTestbed.sh testLabel lpf.${txp}.${numTransmits}.$rate \
    txp $txp \
    senderMap map.none \
    receiverMap map.nonroot \
    rootMap map.0 \
    numTransmits $numTransmits\
    bufferWidth $bufferWidth\
    maxDepth 6 \
    fps 40 \
    $floodOptions\
    $rateOptions \
    cxEnableSkewCorrection 1
  sleep $testDuration

  #idle: do not correct for skew
  ./installTestbed.sh testLabel lpf.${txp}.${numTransmits}.$rate \
    txp $txp \
    senderMap map.none \
    receiverMap map.nonroot \
    rootMap map.0 \
    numTransmits $numTransmits\
    bufferWidth $bufferWidth\
    maxDepth 6 \
    fps 40 \
    $floodOptions\
    $rateOptions \
    cxEnableSkewCorrection 0
  sleep $testDuration
done 
