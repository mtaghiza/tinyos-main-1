#!/bin/bash
function runTestbed(){
  testDuration=$((30 * 60))
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
  # 3 validation: 60 fps, pl=12
  fps=60
  tpl=12
  mdr=100

  for ppd in 75
  do
    for efs in 1 0
    do
      for xt2dc in 1 0
      do
        runTestbed map maps/flat/map.flat.0 pa 0 efs $efs ppd $ppd mdr $mdr tpl $tpl fps $fps td 0 ts 1 xt2dc $xt2dc
      done
    done
  done
done
