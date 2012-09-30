#!/bin/bash
logDir=$1
dbDir=$2

mkdir -p $dbDir

set -x 
for log in $logDir/*
do
  bn=$(basename $log | rev | cut -d '.' -f 1 --complement | rev)
  ./processing_scripts/processBER.sh $log $dbDir/$bn.db
done
