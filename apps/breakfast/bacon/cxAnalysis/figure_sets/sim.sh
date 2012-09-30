#!/bin/bash
sd=fig_scripts/
od=output/sim
connDb=data/conn/db/conn_0922.log.db

set -x
#Dump flood db contents to CSV
testbedCSV=$(tempfile -d tmp)
floodCountCSV=$(tempfile -d tmp)
echo "src,dest,sn,depth" > $testbedCSV
for fn in data/cx/all_floods/*
do
sqlite3 $fn >> $testbedCSV <<EOF
.mode csv
.header off
SELECT src, dest, sn, depth FROM rx_all WHERE src=0;
EOF
sqlite3 $fn >> $floodCountCSV <<EOF
.mode csv
.header off
SELECT ts from tx_all WHERE src=0;
EOF
done

simOptions=""
simCSVs=$(tempfile -d tmp)

numSims=$(wc -l < $floodCountCSV)
for independentLoss in 0 1
do
  for noCaptureLoss in 0.4
  do
    for captureThreshold in 10
    do
      simCSV=$(tempfile)
      simCSVs="$simCSVs $simCSV"
  
      python $sd/TestbedMap.py $connDb --sim \
        --simRuns $numSims --outFile \
        --captureThresh $captureThreshold \
        --noCaptureLoss $noCaptureLoss \
        --independent $independentLoss \
        --outFile $od/sim_${noCaptureLoss}_${captureThreshold}_ind_${independentLoss}.png \
        --text \
        > $simCSV
  
      simOptions="$simOptions --csv $simCSV sim_${noCaptureLoss}_${captureThreshold}_ind_${independentLoss}"
    done
  done
done

R --no-save --slave --args \
  --csv $testbedCSV testbed \
  --labels sim \
  $simOptions \
  --pdf $od/sim.pdf \
  < $sd/depth_comparison_distribution.R

rm $floodCountCSV
rm $testbedCSV
rm $simCSVs
