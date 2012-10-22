#!/bin/bash

testDuration=$((60*60))
for i in $(seq 6)
do
  ./tests/final/flood.sh $testDuration $i
done
