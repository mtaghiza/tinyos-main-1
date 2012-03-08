#!/bin/bash

mkdir -p figures
while [ $# -gt 0 ]
do
    data=$1

    python scripts/framing.py $data \
        > $data.framing
    set -x
    R --no-save --slave --args \
      outPrefix=figures/$(basename $data)\
      framingDataFile=$data.framing \
      < scripts/framing.R

    shift 1
done

