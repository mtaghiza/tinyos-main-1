#!/bin/bash

function runTestbed(){
  testDuration=$((60 * 60))
  installTS=$(date +%s)
  for i in $(seq 1)
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
  #multitier: fix frames per slot, vary routers, test at idle and
  # active
  for map in map.patches.8 map.patches.1 map.patches.4 
  do
    tdel=$(grep '#tdel' $map | cut -d ' ' -f 2)
    ts=$(grep '#ts' $map | cut -d ' ' -f 2)
    for ppd in 50 0 
    do
      runTestbed efs 1 ppd $ppd map $map mdr 100 fps 60 td 0 tpl 100 tdel $tdel ts $ts rp 0xC3
    done
  done
  
  #overhead: fix frames per slot, vary packets per download
  for ppd in 25 50 100
  do
    runTestbed efs 1 ppd $ppd map map.patches.1 mdr 100 fps 60 td 0 tpl 100
  done

  #overhead: fix packets per download, vary frames per slot
  for fps in 30 60 90 120
  do
    runTestbed efs 1 ppd 50 map map.patches.1 mdr 100 fps $fps td 0 tpl 100
  done
  
done
