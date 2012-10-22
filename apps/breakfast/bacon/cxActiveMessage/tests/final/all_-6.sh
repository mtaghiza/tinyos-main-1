#!/bin/bash
testDuration=$((60*60))
txp=0x2D

#11 setups: note that these have a large enough routing table to
#   accomodate all nodes.
# 1 data point: 10 PM wednesday
# 2 data points: 9 AM thurs
# 3 data points: 8 PM thurs
# 4 data points: 7 AM fri
# 5 data points: 6 AM saturday
for i in $(seq 100)
do
  #1 setup: root sends schedules in rapid succession, just get good
  #  data on root->node distances
  ./tests/final/depth.sh $testDuration $txp $i
  #1 setup: nodes send data via flood. baseline performance.
  ./tests/final/flood.sh $testDuration $txp $i
  #1 setup: no data, schedule only.
  ./tests/final/idle.sh $testDuration $txp $i
  #4 setups: buffer width impact for values 1, 2, 3, 5
  ./tests/final/bw.sh $testDuration $txp $i
  #3 setups: selection method impact for buffer width 0
  ./tests/final/selection.sh $testDuration $txp $i
  #1 setup: nodes send as much data as they can via MR burst
  ./tests/final/distance_throughput.sh $testDuration $txp $i
done
