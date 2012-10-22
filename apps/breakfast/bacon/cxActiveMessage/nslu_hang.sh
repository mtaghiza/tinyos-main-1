#!/bin/bash
f=$1
# grab the lines from nslu15 (nodes 22 and 23)
awk '/^[0-9]*\.[0-9]* (22|23)/{print $0}' $f > tmp.txt

# get the TS delta between adjacent log messages
awk '{print $1-last; last=$1}' < tmp.txt > tmp.delta

# count up how often each delta appears in a run:
#  e.g. if there are 20 messages printed within 10 ms of each other,
#  this will show up as 0 20 (since the timestamp is given in 100th of
#  second intervals)
awk '($1 == last){count++}($1 != last){print last, count; last=$1; count=0}' < tmp.deltas > tmp.delta_runs 

# finally, count up how often each run occurred and order by length of
# run. this is mainly to clear up the clutter because there are lots
# of short delta runs.
awk '{run_counts[$0]++}END{for (r in run_counts){ print r, run_counts[r]}}' < tmp.delta_runs | sort -n -k 2

#So things like this would look suspicious:
# ... 
# 0.02 2 1
# 0 2 1334
# 0 3 46
# 0 4 95
# 0 5 37
# 0 6 78
# 0 7 21
# 0 8 24
# 0 9 7
# 0 10 3
# 0 11 4
# 0 12 1
# 0 22 1
# 0 52 1
# 0 61 1
# 0 81 1
# 0 154 1
# 0 208 1
# 0 225 1
# 0 238 1
# 0 300 1
# 0 349 1
# 0 351 1
# 0 371 1

#because we can see a bunch of cases where 100's of messages got spit
# out within ms of each other.
