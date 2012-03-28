#!/bin/bash
while [ $# -gt 0 ]
do 
  f=$1
  d=$(dirname $0)/../internal_timing/$(basename $f)
  aggF=$d/../agg_$(basename $f)

  mkdir -p $d
  awk '/handled/{print 0,$8}' $f >> $d/sfd_sched.csv
  awk '/handled/{print 0,$10}' $f >> $d/sched_handled.csv
  awk '/handled/{print 0,$12}' $f >> $d/sfd_handled.csv

  echo "SR,Event,min,q5,median,q95,max,mean,sd" > $aggF
  for sf in $d/*.csv
  do
    echo -n "$(basename $d | cut -d '_' -f 1) $(basename $sf | cut -d '.' -f 1) "
    R --slave --no-save --args dataFile=$sf inTicks=TRUE < stats.R \
      | cut -d ' ' -f 1 --complement 
  done  | tr ' ' ',' >> $aggF
  shift 1
done
