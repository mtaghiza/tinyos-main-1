#!/bin/bash
set -x 
#FEC one-hop testing
testDuration=3600
#CX flood/non-flood 

for floodTest in 0 1
do
  for mapset in "nonrootRx map.nonroot nonrootTx map.none" "nonrootTx map.nonroot nonrootRx map.none" 
  do
    for fec in 0 1
    do
      ./installTestbed.sh autoRun 1 fecEnabled $fec initSR 100 \
        debugScale 2 $mapset fps 30
      sleep $testDuration
    done
  done
done

for initSR in 50 125 
do
  for fec in 1 0 
  do
    ./installTestbed.sh autoRun 1 fecEnabled $fec initSR $initSR \
      nonrootRx map.onehop nonrootTx map.none fps 5 debugScale 4
    testStart=$(date +%s)
    pushd .
    cd ../sniffer
    make bacon2 SYMBOLRATE=$initSR install bsl,/dev/ttyUSB0 
    python rawSerialTS.py /dev/ttyUSB0 \
      > fec/sm_7_np_4_fec_${fec}_sr_${initSR}_nc_7_ts_$testStart &
    snifferPID=$!
    popd 
    sleep $testDuration
    kill $snifferPID
  done
done
