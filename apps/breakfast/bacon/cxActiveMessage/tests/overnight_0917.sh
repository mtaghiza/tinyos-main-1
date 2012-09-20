#!/bin/bash

conditionalPrrOptions="forceSlots 2 maxDepth 2 fps 5 staticScheduler 1 rootTxp 0xC3 leafTxp 0x8D"
berOptions="forceSlots 2 maxDepth 2 fps 5 rootTxp 0xC3 leafTxp 0x8d staticScheduler 1 fwdDropRate 0x80"

shortDuration=$((60*60))
longDuration=$((2 * 60 * 60))

for i in $(seq 1 10)
do
  ./installTestbed.sh testLabel conditionalPrr.${i} \
    receiverMap map.cprr_senders \
    snifferMap map.cprr_non_senders \
    rootMap map.0 \
    $conditionalPrrOptions
  
  sleep $longDuration
  
  for setup in tests/berMaps/good tests/berMaps/bad
  do
    ./installTestbed.sh testLabel ber.${setup}.${i} \
      receiverMap $setup \
      senderMap map.none \
      snifferMap map.4 \
      rootMap map.5 \
      $berOptions
    sleep $longDuration
  done
done
