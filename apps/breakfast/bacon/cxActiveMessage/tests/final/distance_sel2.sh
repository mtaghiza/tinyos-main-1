#!/bin/bash
testDuration=$((60*60))

for i in $(seq 100)
do
  ./tests/final/distance_prrdc.sh $testDuration $i
  ./tests/final/distance_throughput.sh $testDuration $i
  ./tests/final/sel_at_bw2.sh $testDuration $i
done
