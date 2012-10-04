#!/bin/bash

data250=data/cx/250K/db
data125=data/cx/fec/db/labeled

outDir=output/fec_capture
sd=fig_scripts

mkdir -p $outDir
options=""
for fn in $data250/* $data125/*
do
  bn=$(basename $fn | sed 's/dmap.none/dmap.none.0/g' | sed 's/^dmap.none/dmap.none.0/g' | sed 's/high/high.1/g')
  captureMargin=$(echo $bn | cut -d '.' -f 4)
  numStrong=$(echo $bn | cut -d '.' -f 3)
  numWeak=$(echo $bn | cut -d '.' -f 7)
  sr=$(echo $bn | cut -d '.' -f 9)
  fecOn=$(echo $bn | cut -d '.' -f 11)
  options="$options --db $fn $(($numWeak + $numStrong)) $sr $fecOn $captureMargin" 
done
R --no-save --slave --args \
  $options\
  --plotType prrAny \
  --sr 125 \
  --png $outDir/prr_v_fecAny_125.png \
  < $sd/fecBer_v_senders.R

R --no-save --slave --args \
  $options\
  --plotType prrAny \
  --sr 250 \
  --png $outDir/prr_v_fecAny_250.png \
  < $sd/fecBer_v_senders.R

R --no-save --slave --args \
  $options\
  --plotType prrFecRX \
  --sr 250 \
  --png $outDir/prr_v_fecRX_250.png \
  < $sd/fecBer_v_senders.R

R --no-save --slave --args \
  $options\
  --plotType prrPass \
  --sr 250 \
  --png $outDir/prr_v_fec_250.png \
  < $sd/fecBer_v_senders.R
   
R --no-save --slave --args \
  $options\
  --plotType ber \
  --sr 250 \
  --png $outDir/ber_v_fec_250.png \
  < $sd/fecBer_v_senders.R
  

R --no-save --slave --args \
  $options\
  --plotType prrPass \
  --sr 125 \
  --png $outDir/prr_v_fec_125.png \
  < $sd/fecBer_v_senders.R
  
R --no-save --slave --args \
  $options\
  --plotType ber \
  --sr 125 \
  --png $outDir/ber_v_fec_125.png \
  < $sd/fecBer_v_senders.R

R --no-save --slave --args \
  $options\
  --plotType prrFecRX \
  --sr 125 \
  --png $outDir/prr_v_fecRX_125.png \
  < $sd/fecBer_v_senders.R
  
