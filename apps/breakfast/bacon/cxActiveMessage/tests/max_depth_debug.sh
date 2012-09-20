#!/bin/bash

./installTestbed.sh \
  targetIpi 61440UL \
  txp 0x8D \
  senderMap map.nonroot\
  receiverMap map.none\
  senderDest 65535UL \
  queueThreshold 10 $@

sleep $((60 * 60))
