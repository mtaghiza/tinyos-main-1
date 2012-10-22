#!/bin/bash
if [ $# -lt 4 ]
then
  echo "Usage: $0 <sr> <channel> <ref> <txp>" 1>&2
  exit 1
fi
sr=$1
channel=$2
ref=$3
txp=$4

make bacon2 TEST_POWER=$txp \
  PAYLOAD_LEN=14 TEST_SR=$sr \
  TEST_CHANNEL=$channel\
  AUTOSEND=1 \
  install,0 bsl,ref,$ref
