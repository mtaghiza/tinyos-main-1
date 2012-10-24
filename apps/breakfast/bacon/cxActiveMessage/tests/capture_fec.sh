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
  #25x2x 5 min = 250 min ~= 4 hr 15 per cycle
  # 1 sr
  for sr in 250 
  do
    #2 fec combinations
    for fecEnabled in 1 0
    do
      #25 sender combinations 
      # 5 maps
      #+ 0, 6, 10, 17, none
    
      for highMap in dmap/dmap.high.0 dmap/dmap.high.6 dmap/dmap.high.10 dmap/dmap.none
      do
    
        # 5 maps
        #none, 1, 2, 3, 4
        for lowMap in dmap/dmap.none dmap/dmap.low.* 
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
            sr $sr
    
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
