#!/bin/bash
set -x 
#FEC one-hop testing
testDuration=3600
for initSR in 250 125 50 100 
do
  for fec in 0 1 
  do
    ./installTestbed.sh autoRun 1 fecEnabled $fec initSR $initSR \
      nonrootRx map.onehop nonrootTx map.none fps 5
    pushd .
    cd ../sniffer
    make bacon2 SYMBOLRATE=$initSR install bsl,/dev/ttyUSB0 
    python rawSerialTS.py /dev/ttyUSB0 > fec/sm_7_np_4_fec_${fec}_sr_${initSR}_nc_7 &
    snifferPID=$!
    popd 
    sleep $testDuration
    kill $snifferPID
  done
done

#CX flood/non-flood 
for floodTest in 0 1
do
  for fec in 0 1
  do
    ./installTestbed.sh autoRun 1 fecEnabled $fec initSr 100 \
      nonrootRx map.none nonrootTx map.nonroot fps 30
    sleep $testDuration
  done
done
