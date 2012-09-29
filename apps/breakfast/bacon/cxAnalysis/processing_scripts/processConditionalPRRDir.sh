#!/bin/bash
if [ $# -lt 3 ]
then
  echo "Usage: $0 <logDir> <dbDir> <rootId>"
  exit 1
fi
logDir=$1
dbDir=$2
rootId=$3
sd=$(dirname $0)

mkdir -p $dbDir
set -x
for f in $logDir/*
do
  bn=$(basename $f | rev | cut -d '.' -f 1 --complement | rev)
  $sd/processConditionalPRR.sh $f $dbDir/$bn.db $rootId
done

