#!/bin/bash

while [ $# -gt 0 ]
do
  f=$1
  d=$(dirname $1)/synch/$(basename $f)
  aggF=$(dirname $1)/synch-processed/agg_$(basename $f)
  [ -e $d ] && rm $d/* && rmdir $d
  [ -e $aggF ] && rm $aggF
  mkdir -p $d
  mkdir -p $(dirname $aggF)

#  python filteredEdgeCompare.py $f 1 1 2 1 4 1 5 1 > $d/tx_gdo_synch.csv
#  python filteredEdgeCompare.py $f 1 1 2 1 4 0 5 0 > $d/rx_gdo_synch.csv
#  python filteredEdgeCompare.py $f 1 0 2 0 4 0 5 0 > $d/rx_gdo_fe_synch.csv
#  python filteredEdgeCompare.py $f 0 1 1 1 3 1 4 0 > $d/gdo_re_delay.csv
#  python filteredEdgeCompare.py $f 6 0 2 1 5 1 3 0 > $d/fwd_fs_delay.csv
#  python edgeCompare.py $f 6 7 1  > $d/fsa_synch.csv
  python filteredEdgeCompare.py $f 0 1 1 1 3 1 4 1 > $d/0_1_synch.csv
  python filteredEdgeCompare.py $f 0 1 2 1 3 1 5 1 > $d/0_2_synch.csv
  python filteredEdgeCompare.py $f 1 1 2 1 4 1 5 1 > $d/1_2_synch.csv
  python filteredEdgeCompare.py $f 6 0 7 0 4 1 3 1 > $d/fsa_synch.csv
  echo "SR,Event,min,q5,median,q95,max,mean,sd" > $aggF
  for sf in $d/*.csv
  do
    echo -n "$(basename $d | cut -d '_' -f 1) $(basename $sf | cut -d '.' -f 1) "
    R --slave --no-save --args dataFile=$sf < stats.R \
      | cut -d ' ' -f 1 --complement 
  done  | tr ' ' ',' >> $aggF
  echo "$f output to $aggF"
#  head -1 $aggF | cut -d ',' -f 1,2,8,9
  cat $aggF | cut -d ',' -f 1,2,8,9
  for mean in $(tail --lines=+2 $aggF | cut -d ',' -f 8)
  do
    echo $mean,$(python sToTicks.py $mean)
  done
  shift 1
done
