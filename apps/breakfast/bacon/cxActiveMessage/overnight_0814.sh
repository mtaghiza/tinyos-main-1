#!/bin/bash
pushd .

#connectivity test: 24 hours
#cd ../connectivityTest
#
#echo "In: $(pwd)"
#./installer.sh
#
#sleep $((24 * 60 * 60))
#popd

#simple flood repeats (24 hours)
tp=f
mr=1
ld=65535UL
ra=0
bw=0
for i in $(seq 10 13)
do
  ./installTestbed.sh nsfb_${tp}_all_${mr}_${bw}.${i} \
    staticScheduler 1 \
    nonrootTx map.nonroot \
    nonrootRx map.none \
    cxBufferWidth $bw \
    mr $mr \
    testRequestAck $ra\
    leafDest $ld
  sleep $((60 * 60))
done

echo "In: $(pwd)"
#test larger buffer zones 2*7 = 14 hrs
tp=ub
mr=1
ld=0
ra=0
for i in $(seq 10 10)
do
  for bw in 0 1 2 3 4 5 6 7
  do
    ./installTestbed.sh nsfb_${tp}_all_${mr}_${bw}.${i} \
      staticScheduler 1 \
      nonrootTx map.nonroot \
      nonrootRx map.none \
      cxBufferWidth $bw \
      mr $mr \
      testRequestAck $ra\
      leafDest $ld
    sleep $((60 * 60 ))
  done
done


