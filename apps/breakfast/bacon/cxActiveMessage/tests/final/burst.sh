#!/bin/bash
testDuration=$((60*60))

for i in $(seq 10)
do
  ./tests/final/bw.sh $testDuration $i
  ./tests/final/selection.sh $testDuration $i
done
