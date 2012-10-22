#!/bin/bash
set -x
txp=0x2D
testDuration=$((60 * 60))
for i in $(seq 100)
do
  ./tests/final/average.sh $testDuration $txp $i
done
