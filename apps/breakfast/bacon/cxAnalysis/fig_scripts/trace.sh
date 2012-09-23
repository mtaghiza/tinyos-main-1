#!/bin/bash
# using: dbg/db/lpb.0x8D.1.3.mid.0.70.1348188938.db
# src 22 
#  12: setup, received
#  13, 15, 16, 17, 18 missed 
if [ $# -lt 4 ]
then
  echo "Usage: $0 <trace_db> <output_dir> <src> [sn ...]" 1>&2
  exit 1
fi
set -x 
traceDb=$1
shift 1
outDir=$1
shift 1
src=$1
shift 1
lastMD5=0
for sn in $@
do
  for count in $(seq 0 10)
  do
    ofn=$outDir/$src.$sn.$count.png
    python fig_scripts/TestbedMap.py $traceDb \
      --trace \
      --src $src \
      --sn $sn \
      --count $count \
      --outFile $ofn
    curMD5=$(md5sum < $ofn)
    if [ "$curMD5" == "$lastMD5" ]
    then
      lastMD5=$curMD5
      break
    fi
    lastMD5=$curMD5
  done
done

#TODO maximum fancy: html file with an image frame for each sn that
# you can click left/right to go through/compare

