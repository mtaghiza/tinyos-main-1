#!/bin/bash
testDuration=60

if [ $# -lt 1 ]
then
  echo "usage: $0 <id>" 1>&2
  exit 1
fi
id=$1
if [ "$id" == "0" ]
then
  ref=JH000355
else
  ref=A9VOOY8P
fi
dev=$(motelist | awk --assign ref=$ref '($1==ref){print $2}')

pgrep -f 'python rawSerialTS.py' | xargs kill
python rawSerialTS.py $dev --label $id | tee desktop/$id.rx &
sleep $testDuration
pgrep -f 'python rawSerialTS.py' | xargs kill
