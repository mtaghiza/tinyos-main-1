#!/bin/bash
if [ $# -lt 1 ]
then
  echo "Usage: $0 db testList"
  echo " Format is "
  echo " src dest hc prr"
  exit 1
fi
db=$1
testList=$2

failRates=(0.0 0.05 0.1 0.2 0.30 0.40 0.50)

while true
do
  for f in ${failRates[@]}
  do
    cat $testList | cut -d ' ' -f 1,2 | while read sd
    do
      ./reliabilityTest.sh $db $sd $f 
    done
  done
done
