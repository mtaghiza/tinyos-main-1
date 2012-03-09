#!/bin/bash

mkdir -p figures
while [ $# -gt 0 ]
do
    data=$1

    python scripts/jitter.py $data --sfdForward \
        > $data.sfd

    python scripts/jitter.py $data --endPacketInterrupt \
        > $data.epi

    python scripts/jitter.py $data --stxForward \
        > $data.stx

    set -x
    R --no-save --slave --args \
      outPrefix=figures/$(basename $data)\
      epiDataFile=$data.epi \
      sfdDataFile=$data.sfd \
      stxDataFile=$data.stx \
      < scripts/jitter.R
   

    shift 1
done
