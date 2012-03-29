#!/bin/bash
rootOnly=0
if [ $# -eq 0 ]
then
  echo "usage: $0 [-o] file..."  1>&2
  echo "  Extract TX event timings from files"  1>&2
  echo "  -o : only root (so we can get strobe-gdo and loadfifo-gdo timings"  1>&2
  exit 1
fi
if [ "$1" == "-o" ]
then
  rootOnly=1
  shift 1
fi
while [ $# -gt 0 ]
do
  f=$1
  d=$(dirname $0)/../processed/$(basename $f)
  aggF=$(dirname $0)/../processed/agg_$(basename $f)
  [ -e $d ] && rm $d/* && rmdir $d
  [ -e $aggF ] && rm $aggF
  mkdir -p $d
  python pulseWidth.py $f 0 1 > $d/packet.csv
  python pulseWidth.py $f 2 1 > $d/fs-strobe.csv
  python pulseWidth.py $f 4 1 > $d/strobe.csv
  python pulseWidth.py $f 6 1 > $d/loadfifo.csv
  python pulseWidth.py $f 7 1 > $d/getpacket.csv
  if [ $rootOnly -eq 1 ]
  then
    python edgeCompare.py $f 4 0 1 > $d/strobe-gdo.csv
    python edgeCompare.py $f 6 0 1 > $d/fifo-gdo.csv
    python edgeCompare.py $f 2 0 1 > $d/fs-gdo.csv
  else 
    python edgeCompare.py $f 0 1 1 | awk '($2 > 0){print $0}' > $d/r_gdo-f_gdo.csv
    python edgeCompare.py $f 1 0 1 | awk '($2 < 0){print $0}' > $d/f_gdo-r_gdo.csv
  fi
  echo "SR,Event,min,q5,median,q95,max,mean,sd" > $aggF
  for sf in $d/*.csv
  do
    echo -n "$(basename $d | cut -d '_' -f 1) $(basename $sf | cut -d '.' -f 1) "
    R --slave --no-save --args dataFile=$sf < stats.R \
      | cut -d ' ' -f 1 --complement 
  done  | tr ' ' ',' >> $aggF
  echo "$f output to $aggF"
  grep "r_gdo-f_gdo" $aggF | cut -d ',' -f 1,8
  python sToTicks.py $(grep "r_gdo-f_gdo" $aggF | cut -d ',' -f 8)
  shift 1
done
