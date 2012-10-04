#!/bin/bash
sd=fig_scripts
outDir=output/desktop_capture_1
dataDir=data/cx/desktop_capture_1/conditionalPrr_db
berDataDir=data/cx/desktop_capture_1/db
fecBerDataDir=data/cx/fec/db

berOptions=""
for fn in $berDataDir/* $fecBerDataDir/*fec1*
do

  #dmap.high.0.dmap.low.1.1.ts.db

  bn=$(basename $fn)
  fec=$(echo "$bn" | grep -c 'fec1')
  #should be "high" or "none"
  varSender=$(echo $bn | cut -d '.' -f 2)
  if [ "$varSender" == "high" ]
  then
    separation=$(echo $bn | cut -d '.' -f 3)
    numVarSenders=1

    otherSenders=$(echo $bn | cut -d '.' -f 5)
    if [ "$otherSenders" == "low" ]
    then
      numOtherSenders=$(echo $bn | cut -d '.' -f 6)
    else
      numOtherSenders=0
    fi
  else 
    separation=nocap
    numVarSenders=0
    otherSenders=$(echo $bn | cut -d '.' -f 4)
    if [ "$otherSenders" == "low" ]
    then
      numOtherSenders=$(echo $bn | cut -d '.' -f 5)
    else
      continue
      numOtherSenders=0
    fi
  fi
  
  berOptions="$berOptions -f $fn $(($numVarSenders + $numOtherSenders)) $separation $fec"

done


prrOptions=""
for fn in $dataDir/*
do

  #dmap.high.0.dmap.low.1.1.ts.db

  bn=$(basename $fn)
  
  #should be "high" or "none"
  varSender=$(echo $bn | cut -d '.' -f 2)
  if [ "$varSender" == "high" ]
  then
    separation=$(echo $bn | cut -d '.' -f 3)
    numVarSenders=1

    otherSenders=$(echo $bn | cut -d '.' -f 5)
    if [ "$otherSenders" == "low" ]
    then
      numOtherSenders=$(echo $bn | cut -d '.' -f 6)
    else
      numOtherSenders=0
    fi
  else 
    separation=nocap
    numVarSenders=0
    otherSenders=$(echo $bn | cut -d '.' -f 4)
    if [ "$otherSenders" == "low" ]
    then
      numOtherSenders=$(echo $bn | cut -d '.' -f 5)
    else
      numOtherSenders=0
    fi
  fi
  
  prrOptions="$prrOptions -f $fn $(($numVarSenders + $numOtherSenders)) $separation"

done

rssi6Options=""
for fn in $dataDir/dmap.high.6.dmap.none.* $dataDir/dmap.none.dmap.low.* 
do
  bn=$(basename $fn)
  
  #should be "high" or "none"
  varSender=$(echo $bn | cut -d '.' -f 2)
  if [ "$varSender" == "high" ]
  then
    separation=$(echo $bn | cut -d '.' -f 3)
    numVarSenders=1

    otherSenders=$(echo $bn | cut -d '.' -f 5)
    if [ "$otherSenders" == "low" ]
    then
      numOtherSenders=$(echo $bn | cut -d '.' -f 6)
    else
      numOtherSenders=0
    fi
  else 
    separation=nocap
    numVarSenders=0
    otherSenders=$(echo $bn | cut -d '.' -f 4)
    if [ "$otherSenders" == "low" ]
    then
      numOtherSenders=$(echo $bn | cut -d '.' -f 5)
    else
      numOtherSenders=0
    fi
  fi
  
  rssi6Options="$rssi6Options -f $fn $(($numVarSenders + $numOtherSenders)) $separation"

done

rssi10Options=""
for fn in $dataDir/dmap.high.10.dmap.none.* $dataDir/dmap.none.dmap.low.* 
do
  bn=$(basename $fn)
  
  #should be "high" or "none"
  varSender=$(echo $bn | cut -d '.' -f 2)
  if [ "$varSender" == "high" ]
  then
    separation=$(echo $bn | cut -d '.' -f 3)
    numVarSenders=1

    otherSenders=$(echo $bn | cut -d '.' -f 5)
    if [ "$otherSenders" == "low" ]
    then
      numOtherSenders=$(echo $bn | cut -d '.' -f 6)
    else
      numOtherSenders=0
    fi
  else 
    separation=nocap
    numVarSenders=0
    otherSenders=$(echo $bn | cut -d '.' -f 4)
    if [ "$otherSenders" == "low" ]
    then
      numOtherSenders=$(echo $bn | cut -d '.' -f 5)
    else
      numOtherSenders=0
    fi
  fi
  
  rssi10Options="$rssi10Options -f $fn $(($numVarSenders + $numOtherSenders)) $separation"

done
 
set -x

R --no-save --slave --args \
  $berOptions \
  --plotType ber \
  --legendX 1 \
  --legendY 1 \
  --aspect square \
  --png $outDir/ber_v_senders.png\
  < $sd/ber_v_senders.R

exit 0
R --args \
  $berOptions \
  --plotType prrAny \
  --aspect square \
  --png $outDir/prr_any_v_senders.png\
  < $sd/ber_v_senders.R

R --no-save --slave --args \
  $berOptions \
  --plotType prrPass \
  --legendX 0 \
  --legendY 0 \
  --aspect square\
  --png $outDir/prr_pass_v_senders.png\
  < $sd/ber_v_senders.R


R --no-save --slave --args \
  $rssi10Options \
  --cap 10\
  --png $outDir/rssi_v_senders_capture_10.png\
  < $sd/rssi_v_senders_capture.R

R --no-save --slave --args \
  $rssi6Options \
  --cap 6\
  --png $outDir/rssi_v_senders_capture_6.png\
  < $sd/rssi_v_senders_capture.R

