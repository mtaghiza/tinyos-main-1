#!/bin/bash
testDuration=$((60*60))

for i in $(seq 100)
do
  ./tests/final/stretch.sh $testDuration $i
done
