#!/bin/bash
#flat-network experiments

function runTestbed(){
  testDuration=$((60 * 60))
  installTS=$(date +%s)
  for i in $(seq 2)
  do
    ./testbed.sh installTS $installTS $@
    sleep 60
  done
  sleep $testDuration
  pushd .
  cd ~/tinyos-2.x/apps/Blink
  ./burn map.all
  sleep 60
  popd
}

while true 
do

  #full-speed ahead: to determine goodput during active period
  # - auto-send
  # - 1-second IPI
  # - single download round
  # - bump up frames per slot so that we get roughly the same number
  #   of packets through when forwarder selection is off as we did
  #   in the dcoss work.
  for efs in 0 1
  do
    runTestbed eas 1 efs $efs dr 1024UL tpl 12 mdr 1 fps 60 td 0
  done

  for efs in 0 1
  do
    runTestbed eas 1 efs $efs dr 61440UL tpl 12 mdr 100 fps 60 td 0
  done
  
  #----
  #retests with forwarder selection off (fix bug with clearTime)
  #
  #full-speed ahead: to determine goodput during active period
  # - auto-send
  # - 1-second IPI
  # - single download round
  for efs in 0
  do
    runTestbed eas 1 efs $efs dr 1024UL tpl 12 mdr 1 fps 40 td 0
  done
  #moderate data level: for validation against original CX
  # - enable auto-send
  # - 60 second packet generation interval
  # - permit multiple download rounds
  # - 40 frames per slot (from original)
  for efs in 0
  do
    runTestbed eas 1 efs $efs dr 61440UL tpl 12 mdr 100 fps 40 td 0
  done


done
