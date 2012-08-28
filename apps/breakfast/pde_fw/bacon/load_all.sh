#!/bin/bash
bin=$1
for d in /dev/ttyUSB*
do
  ./load_bacon2.sh $d $bin
done
