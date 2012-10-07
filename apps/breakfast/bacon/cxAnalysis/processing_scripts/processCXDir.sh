#!/bin/bash
if [ $# -lt 2 ]
then
  echo "Usage: $0 <logDir> <dbDir>"
  exit 1
fi
logDir=$1
dbDir=$2
sd=$(dirname $0)

mkdir -p $dbDir
set -x
for f in $logDir/*.log
do
  bn=$(basename $f | rev | cut -d '.' -f 1 --complement | rev)
  $sd/processCXLog.sh $f $dbDir/$bn
done
