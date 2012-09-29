#!/bin/bash
if [ $# -lt 2 ]
then
  echo "Usage: $0 <logDir> <dbDir>"
  exit 1
fi
logDir=$1
dbDir=$2
sd=$(dirname $0)

set -x
mkdir -p $dbDir
for f in $logDir/*
do
  bn=$(basename $f | rev | cut -d '.' -f 1 --complement | rev)
  $sd/processCXTrace.sh $f $dbDir/$bn.db
done

