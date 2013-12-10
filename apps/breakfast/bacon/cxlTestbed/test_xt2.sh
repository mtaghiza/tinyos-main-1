#!/bin/bash

function blinkAll(){
  pushd .
  cd ~/tinyos-2.x/apps/Blink
  ./burn map.all
  sleep 60
  ./burn map.all
  sleep 60
  popd
}

function installNodes(){
  installTS=$(date +%s)
  ./testbed.sh installTS $installTS $@
}

fps=60
tpl=12
mdr=100
ppd=75
efs=0
xt2dc=1

#blinkAll

installNodes map maps/flat/map.leafOnly.0 pa 0 efs $efs ppd $ppd \
          mdr $mdr tpl $tpl fps $fps td 0 ts 1 xt2dc $xt2dc enablePrintf 0

installNodes map maps/flat/map.rootOnly.0 pa 0 efs $efs ppd $ppd \
          mdr $mdr tpl $tpl fps $fps td 0 ts 1 xt2dc $xt2dc enablePrintf 1
