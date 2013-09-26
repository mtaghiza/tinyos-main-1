#!/bin/bash
testDuration=$((60 * 30))

while true
do
  for pa in 0 1
  do
    for txp in 0x2D 
    do
      for eas in 0
      do
        for fps in 30 
        do
          for dr in 1024
          do
            for mct in 2 4 8
            do
              ./testbed.sh eas $eas fps $fps dr $dr rp $txp lp $txp pa $pa mct $mct
              sleep $testDuration
              pushd .
              cd ~/tinyos-2.x/apps/Blink
              ./burn map.all
              sleep 60
              popd
            done
          done
        done
      done
    done
  done
done
