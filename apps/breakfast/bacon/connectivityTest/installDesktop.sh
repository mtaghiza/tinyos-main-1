#!/bin/bash
set -x
testDuration=$(( 60 * 5 ))
testNum=0

if [ $# -gt 0 ]
then 
  testNum=$1
fi

#kill any remaining processes
if [ $(pgrep -c -f 'python rawSerialTS.py') -ne 0 ]
then
  pgrep -f 'python rawSerialTS.py' | xargs kill
fi

#for each attached mote
for ref in $(motelist | awk '/USB/{print $1}')
do
  #pull ID/dev out of programmer
  id=$(echo "$ref" | cut -c 1-5 --complement)
  dev=$(motelist | awk --assign ref=$ref '($1 == ref){print $2}')

  #install sender app
  make bacon2 \
    TEST_POWER=0xC3 PAYLOAD_LEN=35 TEST_SR=125 AUTOSEND=1\
    install,$id bsl,ref,$ref 

  #dump contents to file
  python rawSerialTS.py $dev > $id.$testNum.log &
  sleep $testDuration
  #kill it
  pgrep -f 'python rawSerialTS.py' | xargs kill
  
  #install blink and return to start dir
  pushd .
  cd ~/tinyos-2.x/apps/Blink
  make bacon2 install bsl,$dev
  popd
done
