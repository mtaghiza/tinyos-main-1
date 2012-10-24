#!/bin/bash
set -x 
declare -A idMapping
#root
idMapping[JH000368]=0
#high
idMapping[JH000323]=1 
#low
idMapping[JH000367]=2
idMapping[JH000301]=3
idMapping[JH000300]=4
idMapping[JH000357]=5
#sniffer
idMapping[JH000353]=6
#unused
idMapping[JH000356]=7

pgrep -f 'python rawSerialTS.py' | xargs kill

testDuration=$((60 * 5))
for i in $(seq 1 100)
do
  #20 combinations, 5 minutes each: 1hr 40min/cycle
  # - so 
  # 1 sr
  for sr in 125 
  do
    #1 fec combination
    for fecEnabled in 1 
    do
      # 5 maps
      #none, 1, 2, 3, 4
      for lowMap in dmap/dmap.none.0 dmap/dmap.low.* 
      do
        # 4 maps
        #none, 0, 6, 10
        for highMap in  dmap/dmap.high.1.20
        do
          #kill any dumps
          pgrep -f 'python rawSerialTS.py' | xargs kill
    
          ./installDesktopVariablePower.sh \
            testLabel $(basename $highMap).$(basename $lowMap).sr.$sr.fec.$fecEnabled.$i \
            snifferMap dmap/dmap.sniffer \
            rootMap dmap/dmap.root \
            receiverMap $lowMap \
            receiverMap2 $highMap \
            fps 4 \
            forceSlots 4 \
            maxDepth 2 \
            fecEnabled $fecEnabled \
            sr $sr \
            channel 64
    
          #start up serial dumps
          for d in /dev/ttyUSB*
          do
            ref=$(motelist | awk --assign dev=$d '($2 == dev){print $1}')
            nodeId=${idMapping[$ref]}
            python rawSerialTS.py $d --label $nodeId --reset 1\
              >> desktop/$nodeId.log &
          done
          sleep $testDuration
    
          #kill 'em
          pgrep -f 'python rawSerialTS.py' | xargs kill
        done
      done
    done
  done
done

cd ~/tinyos-2.x/apps/Blink
make bacon2
for d in /dev/ttyUSB*
do
  make bacon2 reinstall bsl,$d
done
