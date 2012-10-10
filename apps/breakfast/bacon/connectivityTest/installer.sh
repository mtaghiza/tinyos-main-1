#!/bin/bash
set -x
TEST_CHANNEL=0
#8D: +0
#C3: +10
TEST_POWER=0xC3
TEST_SR=125
PAYLOAD_LEN=14
#MAP=map.bacon2
MAP=map.all
BURN_TIME=60

if [ $# -gt 0 ]
then
  TEST_POWER=$1
fi

make bacon2 TEST_CHANNEL=$TEST_CHANNEL TEST_POWER=$TEST_POWER\
  PAYLOAD_LEN=$PAYLOAD_LEN TEST_SR=$TEST_SR
#set up everybody
for id in $(grep -v '#' $MAP \
  | awk '{ print $2}')
do
  make bacon2 reinstall,$id wpt,$MAP
done
 
sleep $(($BURN_TIME))
