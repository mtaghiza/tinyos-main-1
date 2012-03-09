#!/bin/bash

mkdir -p figures
while [ $# -gt 0 ]
do
    data=$1
    python scripts/forwardDelay.py $data \
        > $data.forwardDelay
    
    set -x
    R --no-save --slave --args \
      outPrefix=figures/$(basename $data)\
      forwardDelayDataFile=$data.forwardDelay \
      < scripts/forwardDelay.R
    shift 1
done
