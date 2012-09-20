#!/bin/bash
#set up for rapid testing
set -x
berOptions="forceSlots 2 maxDepth 2 fps 5 rootTxp 0xC3 leafTxp 0x8d staticScheduler 1"
testDuration=$((10*60))

#bad links at 0x8d:
# 5 ->
#      8
#      13
#      41
#      43
#      48
#      52
#      61

# good links at 0x8d
# 5 -> 6, 7, 9, 11, 21, 38, 42, 55, 58
for i in $(seq 100)
do
#  for setup in tests/berMaps/bad
#  do
#    ./installTestbed.sh testLabel ber.${setup}.${i}\
#      receiverMap $setup \
#      senderMap map.none \
#      snifferMap map.4 \
#      rootMap map.5 \
#      $berOptions
#    sleep $(( 4 * $testDuration ))
#  done
  
  for setup in tests/berMaps/bad.*
  do
    ./installTestbed.sh testLabel ber.${setup}.${i} \
      receiverMap $setup \
      senderMap map.none \
      snifferMap map.4 \
      rootMap map.5 \
      $berOptions
    sleep $testDuration
  done
done
