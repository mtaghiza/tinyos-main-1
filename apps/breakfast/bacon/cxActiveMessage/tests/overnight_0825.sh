#!/bin/bash
pushd .

#connectivity test: 24 hours
#
#echo "In: $(pwd)"
#./installer.sh
#
#sleep $((24 * 60 * 60))
#popd


# 2x 15 =30 hours
for i in 40 41
do
  #simple flood + retx
  tp=f
  mr=1
  ld=65535UL
  ra=0
  bw=0
  dc=1
  #3 hours
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

  echo "In: $(pwd)"
  tp=ub
  mr=1
  ld=0
  ra=0
  bw=1
  dc=1
  #3x4=12 hr
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


#4 hour loop, repeat 
for i in $(seq 42 100)
do
  #simple flood 
  tp=f
  mr=1
  ld=65535UL
  ra=0
  bw=0
  dc=1
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

  tp=ub
  mr=1
  ld=0
  ra=0
  bw=1
  dc=1
  for bw in 0 1 3
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

