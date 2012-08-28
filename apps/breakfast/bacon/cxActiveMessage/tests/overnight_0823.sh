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
dc=1
for i in $(seq 30 30)
do
  for mr in 1 2 3
  do
    ./installTestbed.sh nsfb_${tp}_all_${mr}_${bw}.${i} \
      staticScheduler 1 \
      nonrootTx map.nonroot \
      nonrootRx map.none \
      fps 40 \
      cxBufferWidth $bw \
      mr $mr \
      cxDutyCycleEnabled $dc\
      testRequestAck $ra\
      leafDest $ld
    sleep $((60 * 60))
  done
done

echo "In: $(pwd)"
tp=ub
mr=1
ld=0
ra=0
bw=1
dc=1
for i in $(seq 20 20)
do
  for bw in 0 1 3 5
  do
    for mr in 1 2 3
    do
      ./installTestbed.sh nsfb_${tp}_all_${mr}_${bw}.${i} \
        staticScheduler 1 \
        nonrootTx map.nonroot \
        nonrootRx map.none \
        fps 40 \
        cxBufferWidth $bw \
        mr $mr \
        cxDutyCycleEnabled $dc\
        testRequestAck $ra\
        leafDest $ld
      sleep $((60 * 60 ))
    done
  done
done


