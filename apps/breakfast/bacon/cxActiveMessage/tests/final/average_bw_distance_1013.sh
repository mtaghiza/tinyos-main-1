#!/bin/bash
testDuration=$(( 60 * 60))
for i in $(seq 100)
do
  ./tests/final/average_bw_distance.sh $testDuration $i
done
