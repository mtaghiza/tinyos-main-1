#!/bin/bash
testDuration=$((60*60))
longTestDuration=$((60*60*4))
floodOptions="senderDest 65535UL requestAck 0"
burstOptions="senderDest 0 requestAck 1"


lowRateOptions='targetIpi 143360UL'

for i in $(seq 100)
do
  #low data rate: set IPI to 140 seconds for 'light' traffic
  #  note that this will most definitely be improved upon when we
  #  tighten up the PFS_SLACK timings etc.
  # 3 x 2 x 4 = 24 hours
  for txp in 0x8D 0x2d 0xc3
  do
    numTransmits=1
    bufferWidth=0
    ./installTestbed.sh testLabel f.low.${txp}.${numTransmits}.${bufferWidth}.${i} \
      txp $txp \
      senderMap map.nonroot \
      receiverMap map.none \
      rootMap map.0 \
      numTransmits $numTransmits\
      $lowRateOptions \
      $floodOptions
    sleep $longTestDuration
  
    ./installTestbed.sh testLabel b.low.${txp}.${numTransmits}.${bufferWidth}.${i} \
      txp $txp \
      senderMap map.nonroot \
      receiverMap map.none \
      rootMap map.0 \
      numTransmits $numTransmits\
      bufferWidth $bufferWidth\
      $lowRateOptions \
      $burstOptions
    sleep $longTestDuration
  done
  
  # 3x 1 = 3 hours
  for txp in 0x8D 0x2D 0xC3
  do
    #idle/baseline duty cycle
    ./installTestbed.sh testLabel idle.${txp}.${i}\
      txp $txp \
      senderMap map.none \
      receiverMap map.nonroot \
      rootMap map.0 \
      numTransmits 1
    sleep $testDuration
  done
  
  
  #single sender flood/burst 
  # 2 x 3 x 1 = 6 hours
  for sender in 20 40
  do
    for txp in 0x2d 0x8d 0xc3
    do
      ./installTestbed.sh testLabel single.f.${txp}.${sender}.${i} \
        txp $txp \
        senderMap map.${sender} \
        receiverMap map.nonroot \
        $burstOptions
      sleep $testDuration
      ./installTestbed.sh testLabel single.b.${txp}.${sender}.${i}\
        txp $txp \
        senderMap map.${sender} \
        receiverMap map.nonroot \
        $floodOptions
      sleep $testDuration
    done
  done
done
