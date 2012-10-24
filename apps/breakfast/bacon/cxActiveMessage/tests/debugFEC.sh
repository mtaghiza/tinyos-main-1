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
for i in $(seq 1 1000)
do
  #30 combinations, ~2.5 hours at 5 minute tests
  # 6 maps
  #+ 0, 4, 6, 10, 17, none
  for highMap in dmap/dmap.high.0 
  do
    # 5 maps
    #none, 1, 2, 3, 4
    for lowMap in dmap/dmap.low.1 
    do
      for sr in 250 125
      do
        for fec in 1 0
        do
          #kill any dumps
          pgrep -f 'python rawSerialTS.py' | xargs kill
          ./installDesktopVariablePower.sh \
            testLabel $(basename $highMap).$(basename $lowMap).fec${fec}.$i \
            rootMap dmap/dmap.root \
            snifferMap dmap/dmap.sniffer\
            receiverMap $highMap \
            receiverMap2 $lowMap \
            fps 10 \
            sr $sr \
            forceSlots 10 \
            maxDepth 3 \
            fecEnabled $fec
    
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


