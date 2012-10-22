#!/bin/bash
if [ $# -lt 2 ]
then
  echo "Usage: $0 <sr> <channel> [mote ref...]" 1>&2
  exit 1
fi
testSR=$1
testChannel=$2
make bacon2 \
  PAYLOAD_LEN=4 TEST_SR=$testSR \
  TEST_CHANNEL=$testChannel \
  AUTOSEND=0 

shift 2
for ref in $@
do
  if [ $(echo $ref | grep -c JH) -gt 0 ]
  then
    make bacon2 reinstall,1 bsl,ref,$ref
  fi
done
