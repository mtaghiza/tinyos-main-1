#!/bin/bash
set -x
sd=fig_scripts
outDir=output/fixed_skew
connDb=data/conn/db/all.log.db

floodLowDb=data/cx/0913/db/f.0x8D.1.low.1347577567.db

floodDb=data/cx/0912/db/f.0x8D.1.mid.1347507546.db

burstMid0Db=data/cx/0913/db/b.0x8D.1.0.mid.1347489286.db
burstMid1Db=data/cx/0913/db/b.0x8D.1.1.mid.1347492938.db
burstMid3Db=data/cx/0913/db/b.0x8D.1.3.mid.1347496590.db
burstMid5Db=data/cx/0913/db/b.0x8D.1.5.mid.1347500242.db
burstMid7Db=data/cx/0913/db/b.0x8D.1.7.mid.1347503894.db


burstLow0Db=data/cx/0913/db/b.0x8D.1.0.low.1347533059.db
burstLow1Db=data/cx/0913/db/b.0x8D.1.1.low.1347540311.db
burstLow3Db=data/cx/0913/db/b.0x8D.1.3.low.1347547564.db
burstLow5Db=data/cx/0913/db/b.0x8D.1.5.low.1347554816.db
burstLow7Db=data/cx/0913/db/b.0x8D.1.7.low.1347562068.db

idleDb=data/cx/0912/db/idle.db
idleNoSkewDb=data/cx/0913/db/idle.noSkewCorrection.1347485635.db

R --no-save --slave  --args \
  -f $floodDb flood_50 \
  -f $burstMid0Db burst_0_43 \
  -f $burstMid1Db burst_1_17 \
  -f $burstMid3Db burst_3_41 \
  -f $burstMid5Db burst_5_38 \
  -f $burstMid7Db burst_7_38 \
  --png $outDir/duty_cycle_mid.png \
  < $sd/duty_cycle_cdf.R

R --no-save --slave  --args \
  -f $floodLowDb flood_110 \
  -f $burstLow0Db burst_0_95 \
  -f $burstLow1Db burst_1_91 \
  -f $burstLow3Db burst_3_88 \
  -f $burstLow5Db burst_5_88 \
  -f $burstLow7Db burst_7_86 \
  --png $outDir/duty_cycle_low.png \
  < $sd/duty_cycle_cdf.R

python $sd/TestbedMap.py $burstMid0Db \
  --dc \
  --outFile $outDir/burst_dc_0.png > /dev/null

python $sd/TestbedMap.py $burstMid1Db \
  --dc \
  --outFile $outDir/burst_dc_1.png > /dev/null

python $sd/TestbedMap.py $burstMid3Db \
  --dc \
  --outFile $outDir/burst_dc_3.png > /dev/null


python $sd/TestbedMap.py $floodDb --cxp --from 0 \
  --outFile $outDir/flood_prr_rl.png \
  > /dev/null
python $sd/TestbedMap.py $floodDb --cxp --to 0 \
  --outFile $outDir/flood_prr_lr.png \
  > /dev/null

python $sd/TestbedMap.py $burstMid0Db --cxp --to 0 --outFile $outDir/ub_bw_0.png > /dev/null
python $sd/TestbedMap.py $burstMid1Db --cxp --to 0 --outFile $outDir/ub_bw_1.png > /dev/null
python $sd/TestbedMap.py $burstMid3Db --cxp --to 0 --outFile $outDir/ub_bw_3.png > /dev/null
python $sd/TestbedMap.py $burstMid5Db --cxp --to 0 --outFile $outDir/ub_bw_5.png > /dev/null


R --no-save --slave  --args \
  -f $floodDb flood_50 \
  -f $burstMid0Db burst_0_43 \
  -f $burstMid1Db burst_1_17 \
  -f $burstMid3Db burst_3_41 \
  -f $burstMid5Db burst_5_38 \
  -f $burstMid7Db burst_7_38 \
  --png $outDir/prr_mid.png \
  < $sd/prr_cdf.R

R --no-save --slave  --args \
  -f $floodLowDb flood_110 \
  -f $burstLow0Db burst_0_95 \
  -f $burstLow1Db burst_1_91 \
  -f $burstLow3Db burst_3_88 \
  -f $burstLow5Db burst_5_88 \
  -f $burstLow7Db burst_7_86 \
  --png $outDir/prr_low.png \
  < $sd/prr_cdf.R


#  -f $burstMid1Db burst_1_12 \
R --no-save --slave  --args \
  -nf $floodDb flood_50 \
  -f $burstMid0Db burst_0_43 \
  -f $burstMid1Db burst_1_17 \
  -f $burstMid3Db burst_3_41 \
  -f $burstMid5Db burst_5_38 \
  -f $burstMid7Db burst_7_38 \
  --png $outDir/duty_cycle_improvement_mid_cdf.png \
  < $sd/duty_cycle_improvement_cdf.R


R --no-save --slave  --args \
  -nf $floodLowDb flood_110 \
  -f $burstLow0Db burst_0_95 \
  -f $burstLow1Db burst_1_91 \
  -f $burstLow3Db burst_3_88 \
  -f $burstLow5Db burst_5_88 \
  -f $burstLow7Db burst_7_86 \
  --png $outDir/duty_cycle_improvement_low_cdf.png \
  < $sd/duty_cycle_improvement_cdf.R


R --no-save --slave  --args \
  -f $floodDb flood_50 \
  -f $floodLowDb flood_105 \
  --png $outDir/prr_flood.png \
  < $sd/prr_cdf.R


R --no-save --slave  --args \
  -f $floodDb flood_50 \
  -f $floodLowDb flood_105 \
  --png $outDir/duty_cycle_flood.png \
  < $sd/duty_cycle_cdf.R

R --no-save --slave  --args \
  -f $idleDb idle \
  -f $idleNoSkewDb idle_no_skew \
  -f $floodDb flood_50 \
  --png $outDir/duty_cycle_cdf_idle.png \
  < $sd/duty_cycle_cdf.R
 
R --no-save --slave --args \
  -f $floodDb 1 \
  --png $outDir/flood_retx.png \
  < $sd/flood_retx.R


R --no-save --slave --args -f $floodDb \
  --png $outDir/flood_depth_asym.png \
  < $sd/flood_depth_asym.R
R --no-save --slave --args -f $floodDb \
  --png $outDir/asym_boxplot.png \
  < $sd/asym_boxplot.R

R --no-save --slave --args -f $floodDb \
  -n 23 \
  --png $outDir/depth_v_time_for_node.png \
  < $sd/depth_v_time_for_node.R

exit 0

