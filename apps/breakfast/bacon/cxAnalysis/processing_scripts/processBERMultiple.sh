#!/bin/bash

if [ $# -lt 2 ]
then 
  echo "Usage: $0 <fecEnabled> <dbDir> [files...]"
  exit 1
fi

fecEnabled=$1
dbDir=$2
shift 2
mkdir -p $dbDir

for log in $@
do
  bn=$(basename $log | rev | cut -d '.' -f 1 --complement | rev)
  set -x
  ./processing_scripts/processBER.sh $log $dbDir/$bn.db $fecEnabled
  set +x
done
