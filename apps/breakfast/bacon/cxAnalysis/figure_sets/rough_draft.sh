#!/bin/bash
set -x
sd=fig_scripts
outDir=rough_draft
connDb=data/conn/db/all.log.db

cxDir=data/cx/lowpower_macro/db

floodDb=data/cx/0907/db/lpf.0x8D.1.high.1347073707.db
floodLowDb=data/cx/0907/db/lpf.0x8D.1.low.1347253698.db

burstHigh0Db=data/cx/0907/db/lpb.0x8D.1.0.high.1347055298.db
burstHigh1Db=data/cx/0907/db/lpb.0x8D.1.1.high.1347058980.db
burstHigh3Db=data/cx/0907/db/lpb.0x8D.1.3.high.1347062662.db
burstHigh5Db=data/cx/0907/db/lpb.0x8D.1.5.high.1347066343.db
burstHigh7Db=data/cx/0907/db/lpb.0x8D.1.7.high.1347070025.db
#burstHigh0Db=data/cx/lowpower_macro_0906/db/lpb.0x8D.1.0.high.1346965999.db
#burstHigh1Db=data/cx/lowpower_macro_0906/db/lpb.0x8D.1.1.high.1346969682.db
#burstHigh3Db=data/cx/lowpower_macro_0906/db/lpb.0x8D.1.3.high.1346973363.db
#burstHigh5Db=data/cx/lowpower_macro_0906/db/lpb.0x8D.1.5.high.1346977046.db
idleDb=data/cx/dc/db/idle.0x8D.1.1346773943.db
idleNoFailDb=data/cx/dc/db/idle_nofail.db

R --no-save --slave  --args \
  -f $floodDb flood_21 \
  -f $burstHigh0Db burst_0_10 \
  -f $burstHigh1Db burst_1_12 \
  -f $burstHigh3Db burst_3_18 \
  -f $burstHigh5Db burst_5_20 \
  -f $burstHigh7Db burst_7_21 \
  -f $floodLowDb flood_105 \
  --png $outDir/duty_cycle_all.png \
  < $sd/duty_cycle_cdf.R

python $sd/TestbedMap.py $burstHigh0Db \
  --dc \
  --outFile $outDir/burst_dc_0.png

python $sd/TestbedMap.py $burstHigh1Db \
  --dc \
  --outFile $outDir/burst_dc_1.png

python $sd/TestbedMap.py $burstHigh3Db \
  --dc \
  --outFile $outDir/burst_dc_3.png


python $sd/TestbedMap.py $floodDb --cxp --from 0 --outFile $outDir/flood_prr_rl.png
python $sd/TestbedMap.py $floodDb --cxp --to 0 --outFile $outDir/flood_prr_lr.png

python $sd/TestbedMap.py $burstHigh0Db --cxp --to 0 --outFile $outDir/ub_bw_0.png
python $sd/TestbedMap.py $burstHigh1Db --cxp --to 0 --outFile $outDir/ub_bw_1.png
python $sd/TestbedMap.py $burstHigh3Db --cxp --to 0 --outFile $outDir/ub_bw_3.png
python $sd/TestbedMap.py $burstHigh5Db --cxp --to 0 --outFile $outDir/ub_bw_5.png


R --no-save --slave  --args \
  -f $floodDb flood_21 \
  -f $burstHigh0Db burst_0_10 \
  -f $burstHigh1Db burst_1_12 \
  -f $burstHigh3Db burst_3_18 \
  -f $burstHigh5Db burst_5_20 \
  -f $burstHigh7Db burst_7_21 \
  -f $floodLowDb flood_105 \
  --png $outDir/prr_all.png \
  < $sd/prr_cdf.R

#  -f $burstHigh1Db burst_1_12 \
R --no-save --slave  --args \
  -nf $floodDb flood_21 \
  -f $burstHigh0Db burst_0_10 \
  -f $burstHigh1Db burst_1_12 \
  -f $burstHigh3Db burst_3_18 \
  -f $burstHigh5Db burst_5_20 \
  -f $burstHigh7Db burst_7_21 \
  -f $floodLowDb flood_105 \
  --png $outDir/duty_cycle_improvement_cdf.png \
  < $sd/duty_cycle_improvement_cdf.R



R --no-save --slave  --args \
  -f $floodDb flood_21 \
  -f $floodLowDb flood_105 \
  --png $outDir/prr_flood.png \
  < $sd/prr_cdf.R


R --no-save --slave  --args \
  -f $floodDb flood_21 \
  -f $floodLowDb flood_105 \
  --png $outDir/duty_cycle_flood.png \
  < $sd/duty_cycle_cdf.R

R --no-save --slave  --args \
  -f $idleDb idle \
  -f $idleNoFailDb idle_no_fail \
  -f $floodDb flood \
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

