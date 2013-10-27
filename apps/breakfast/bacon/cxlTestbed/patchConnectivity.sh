#!/bin/bash

function runTestbed(){
  testDuration=$((10*60))
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
  ./burn map.all
  sleep 60
  popd
}

while true
do
  #check router tier and each patch individually on channel 0, router at normal (-6)
  # tx power
  for map in maps/routers/routers maps/individual/* 
  do
    tdel=$(grep '#tdel' $map | cut -d ' ' -f 2)
    ts=$(grep '#ts' $map | cut -d ' ' -f 2)
    for ppd in 20
    do
      for settings in "pa 0 rxSlack 15UL"
      do
        runTestbed efs 1 ppd $ppd map $map sdel 20480UL mdr 100 fps 60 td 0 tpl 100 tdel $tdel ts $ts rp 0x2D $settings
      done
    done
  done
  
#   #check full network on a range of channels
#   for map in maps/flat/*
#   do
#     tdel=$(grep '#tdel' $map | cut -d ' ' -f 2)
#     ts=$(grep '#ts' $map | cut -d ' ' -f 2)
#     for ppd in 50
#     do
#       runTestbed efs 1 ppd $ppd map $map mdr 100 fps 60 td 0 tpl 100 tdel $tdel ts $ts rp 0x2D
#     done
#     
#   done

done
