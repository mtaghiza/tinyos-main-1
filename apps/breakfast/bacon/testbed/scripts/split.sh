#!/bin/bash

if [ $# -lt 2 ]
then
  echo "Usage: $0 logFile outDir [rootId=0]"
  exit 1
fi

logFile=$1
outDir=$2
rootId=0

mkdir -p $outDir
shift 2

if [ $# -gt 0 ]
then
  rootId=$1
fi

tf=$(tempfile)
dos2unix -n $logFile $tf
startLine=$(grep -n " $rootId START " $tf | head -1 | awk -F ':' '{print $1}')
endLine=$(grep -n " $rootId START " $tf | head -2 | tail -1 | awk -F ':' '{print $1}')
if [ "$startLine" == "$endLine" ]
then
  endLine=$(wc -l < $tf)
fi

echo "start: $startLine end: $endLine"
while [ "$startLine" != "$endLine" -a "$startLine" != "" ]
do
  of=$outDir/$(head --lines=$startLine $tf | tail -1 | tr '=' ' ' | awk '{
    ts=$1
    for (k=1; k < NF; k++){
      if ($k == "LABEL"){
        label=$(k+1)
      }
      if ($k == "HASH"){
        hash=$(k+1)
      }
      if ($k == "SCRIPT"){
        script=$(k+1)
      }
    }
    printf("%i_%s_%s_%s\n", 
      ts, label, script, hash)
  }').log
  echo "creating $of ( $(wc -l < $tf) lines remain)."
  head --lines=$(($endLine - 1)) $tf | tail --lines=+$startLine > $of
  tail --lines=+$endLine $tf > $tf.0
  mv $tf.0 $tf

  startLine=$(grep -n " $rootId START " $tf | head -1 | awk -F ':' '{print $1}')
  endLine=$(grep -n " $rootId START " $tf | head -2 | tail -1 | awk -F ':' '{print $1}')

  echo "start: $startLine end: $endLine"
  if [ "$endLine" == "" -o "$startLine" == "$endLine" ]
  then
    endLine=$(wc -l < $tf)
    echo "no end line, use file length: $endLine"
  fi
done

rm $tf
