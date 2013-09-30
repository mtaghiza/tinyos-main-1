#!/bin/bash

duration=$((60*60))
for trials in $(seq 3)
do
  for channel in 0 32 64 96 128 160 192 224 255
  do
    ./testbed.sh channel $channel
    sleep $duration
  done
done
