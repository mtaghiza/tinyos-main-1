#!/bin/bash
testDuration=$(60 * 30)

while true
do
  for eas in 0 1
  do
    for fps in 30 60 90
    do
      for dr in 1024
      do
        pushd .
        cd ~/tinyos-2.x/apps/Blink
        ./burn map.all
        sleep 60
        popd
        ./testbed.sh eas $eas fps $fps dr $dr
        sleep $testDuration
      done
    done
  done
done
