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
  d=../processed/$(basename $f)
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
  fi
  echo "SR,Event,min,q5,median,q95,max,mean,sd" > ../processed/agg_$(basename $f)
  for sf in $d/*.csv
  do
    echo -n "$(basename $d | cut -d '_' -f 1) $(basename $sf | cut -d '.' -f 1) "
    R --slave --no-save --args dataFile=$sf < stats.R \
      | cut -d ' ' -f 1 --complement 
  done  | tr ' ' ',' >> ../processed/agg_$(basename $f)
  shift 1
done
