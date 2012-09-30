#!/bin/bash
sd=fig_scripts
outDir=output/capture
mkdir -p $outDir

noCapArgs=""
fileList=$(grep 'nocap' data/cx/capVSenders_retest/valid_cprr) 
for fn in $fileList
do
  numSenders=$(basename $fn | cut -d '.' -f 3)
  noCapArgs="$noCapArgs -f $fn $numSenders no_cap"
done

cap20Args=""
fileList=$(grep 'capOnly.20' data/cx/capVSenders_retest/valid_cprr)
for fn in $fileList
do
  numSenders=1
  cap20Args="$cap20Args -f $fn $numSenders cap_20"
done
fileList=$( grep 'map.200.capVSenders.*.20.0x8D' data/cx/capVSenders_retest/valid_cprr ) 
for fn in $fileList
do
  numSenders=$((1 + $(basename $fn | cut -d '.' -f 4)))
  cap20Args="$cap20Args -f $fn $numSenders cap_20"
done

cap10Args=""
fileList=$(grep 'capOnly.0x8D' data/cx/capVSenders_retest/valid_cprr)
for fn in $fileList
do
  numSenders=1
  cap10Args="$cap10Args -f $fn $numSenders cap_10"
done
fileList=$( grep 'map.200.capVSenders' data/cx/capVSenders_retest/valid_cprr | grep -v '20.0x8D' )
for fn in $fileList
do 
  numSenders=$(( 1 + $(basename $fn | cut -d '.' -f 4)))
  cap10Args="$cap10Args -f $fn $numSenders cap_10"
done


# #-----------------------
##capture v. senders
echo "NO cap: $noCapArgs"
echo "10db cap: $cap10Args"
echo "20db cap: $cap20Args"

echo ""
echo ""
set -x 
R --no-save --slave --args \
  $noCapArgs \
  $cap10Args \
  $cap20Args \
  --png $outDir/prr_v_senders.png \
  < $sd/prr_v_senders.R


