#!/bin/bash
testDuration=$((60*60))

#9-hour cycle: 4 runs of each by sunday morning
for i in $(seq 100)
do
  #1 setup
  ./tests/final/flood.sh $testDuration $i
  #1 setup
  ./tests/final/idle.sh $testDuration $i
  #4 setups
  ./tests/final/bw.sh $testDuration $i
  #3 setups
  ./tests/final/selection.sh $testDuration $i
done
#hopefully error rate is pretty low
#then, on sunday do the connectivity test with FEC
#and then we'll be able to set up for the distance-dependence and
# fault-tolerance tests, hopefully those results come in OK
