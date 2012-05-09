#!/bin/bash
set -x 
testDuration=3600
#CX flood/non-flood 

for i in $(seq 2)
do
  for initSR in 125 100
  do
    for floodTest in 1 0
    do
      for mapset in "nonrootRx map.none nonrootTx map.nonroot" 
      do
        ./installTestbed.sh autoRun 1 fecEnabled 0 initSR 125 \
          debugScale 3 $mapset fps 30 floodTest $floodTest
        sleep $testDuration
      done
    done
  done
done

exit 0
#FEC one-hop testing
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
