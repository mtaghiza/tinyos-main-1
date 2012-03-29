#!/bin/bash

while [ $# -gt 0 ]
do
  f=$1
  d=$(dirname $0)/../synch/$(basename $f)
  aggF=$(dirname $0)/../synch-processed/agg_$(basename $f)
  [ -e $d ] && rm $d/* && rmdir $d
  [ -e $aggF ] && rm $aggF
  mkdir -p $d
  mkdir -p $(dirname $aggF)

  python filteredEdgeCompare.py $f 0 1 1 1 2 1 3 1 > $d/synch.csv
  echo "SR,Event,min,q5,median,q95,max,mean,sd" > $aggF
  for sf in $d/*.csv
  do
    echo -n "$(basename $d | cut -d '_' -f 1) $(basename $sf | cut -d '.' -f 1) "
    R --slave --no-save --args dataFile=$sf < stats.R \
      | cut -d ' ' -f 1 --complement 
  done  | tr ' ' ',' >> $aggF
  echo "$f output to $aggF"
  grep "synch" $aggF | cut -d ',' -f 1,8,9
  python sToTicks.py $(grep "synch" $aggF | cut -d ',' -f 8)

  shift 1
done
