#!/bin/bash
if [ $# -lt 4 ]
then
  echo "Usage: $0 <outputDir> <prefix> <test list file> <testbed log>" 1>&2 
  exit 1
fi
outdir=$1
prefix=$2
testList=$3
testbedLog=$4

#set -x 
lastFile=""
#for each test setup
grep -v '#' $testList | while read line
do
  isEndMarker=$(echo $line | grep -c END)
  #pull the start timestamp, plus the test parameters
  start=$(echo $line | awk '{print $2}')
  fec=$(echo $line | awk '{print $4}')
  sr=$(echo $line | awk '{print $6}')
  flood=$(echo $line | awk '{print $8}')
  rx=$(echo $line | awk '{print $10}')
  tx=$(echo $line | awk '{print $12}')
  #construct a filename for this setup
  fn=${outdir}/${prefix}_fec_${fec}_sr_${sr}_flood_${flood}_rx_${rx}_tx_${tx}_ts_${start}
  
  #cut out everything from the previous output file that overlaps with
  #  the current test
  if [ "$lastFile" != "" ]
  then
    echo "ET $start $lastFile"
    awk --assign et=$start '($1 < et){print $0}' $lastFile > $lastFile.tmp
    mv ${lastFile}.tmp ${lastFile}
  fi
  if [ $isEndMarker -eq 0 ]
  then
    echo "ST $start $fn"
    #take any lines from the original log where timestamp > test start time
    awk --assign st=$start '($1 > st){print $0}' $testbedLog > $fn
    lastFile=$fn
  fi
done 
