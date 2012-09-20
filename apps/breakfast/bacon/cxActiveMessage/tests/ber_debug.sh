#!/bin/bash
#set up for rapid testing
set -x
berOptions="forceSlots 2 maxDepth 2 fps 5 txp 0x25 staticScheduler 1"
testDuration=$((60*60))

setup=tests/ber_maps/good.7
./installTestbed.sh testLabel ber.${setup}.debug \
  receiverMap $setup \
  senderMap map.none \
  snifferMap map.1 \
  rootMap map.0 \
  $berOptions
