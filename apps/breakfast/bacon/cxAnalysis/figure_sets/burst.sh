#!/bin/bash
dbDir=data_final/testbed/db
outDir=output/burst
sd=fig_scripts
mkdir -p $outDir

bwOptions=""
selOptions=""
floodOptions=""
for f in $dbDir/*.db
do
  bn=$(basename $f)
  t=$(echo $bn | cut -d '.' -f 2)
  if [ "$t" == "burst" ]
  then
    bw=$(echo $bn | cut -d '.' -f 4)
    sel=$(echo $bn | cut -d '.' -f 6)
    if [ "$sel" == "2" ]
    then
      bwOptions="$bwOptions --db $f $bw 1"
    fi
    if [ "$bw" == "0" ]
    then
      echo "$f $t $bw $sel"
      selOptions="$selOptions --db $f $sel 1"
    fi
  elif [ "$t" == "flood" ]
  then
    echo "$f $t $bw $sel"
    floodOptions="$floodOptions --ndb $f flood 0"
  elif [ "$t" == "idle" ]
  then
    echo "idle"

  fi
done

set -x

R --no-save --slave --args \
  --dir lr \
  $floodOptions \
  --pdf $outDir/prr_flood.pdf \
  < $sd/prr_cdf_ggplot.R

R --no-save --slave --args \
  $floodOptions \
  --pdf $outDir/dc_flood.pdf \
  < $sd/duty_cycle_cdf_ggplot.R

R --no-save --slave --args \
  $bwOptions \
  $floodOptions \
  --pdf $outDir/dci_v_bw.pdf \
  < $sd/duty_cycle_improvement_cdf_ggplot.R

R --no-save --slave --args \
  $selOptions \
  $floodOptions \
  --pdf $outDir/dci_v_sel.pdf \
  < $sd/duty_cycle_improvement_cdf_ggplot.R

R --no-save --slave --args \
  $selOptions \
  $floodOptions \
  --pdf $outDir/dc_v_sel.pdf \
  < $sd/duty_cycle_cdf_ggplot.R

R --no-save --slave --args \
  $bwOptions \
  $floodOptions \
  --pdf $outDir/dc_v_bw.pdf \
  < $sd/duty_cycle_cdf_ggplot.R

R --no-save --slave --args \
  --dir lr \
  $selOptions \
  $floodOptions \
  --pdf $outDir/prr_v_sel.pdf \
  < $sd/prr_cdf_ggplot.R

R --no-save --slave --args \
  --dir lr \
  $bwOptions \
  $floodOptions \
  --pdf $outDir/prr_v_bw.pdf \
  < $sd/prr_cdf_ggplot.R

