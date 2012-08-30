#!/bin/bash
dbDir=data/0825/db
outDir=fixed_settings

set -x
R --no-save --slave --args -f $dbDir/nsfb_f_all_1_0.40.db \
  --png $outDir/asym_boxplot.png \
  < fig_scripts/asym_boxplot.R

R --no-save --slave --args -f $dbDir/nsfb_f_all_1_0.40.db \
  --png $outDir/flood_depth_asym.png \
  < fig_scripts/flood_depth_asym.R

R --no-save --slave --args -f $dbDir/nsfb_f_all_1_0.40.db \
  --png $outDir/asym_boxplot.png \
  < fig_scripts/asym_boxplot.R

R --no-save --slave --args -f $dbDir/nsfb_f_all_1_0.40.db \
  --png $outDir/depth_v_time_35.png \
  < fig_scripts/depth_v_time_35.R

R --no-save --slave --args -f $dbDir/nsfb_f_all_1_0.40.db \
  --png $outDir/flood_prr_asym.png \
  < fig_scripts/flood_prr_asym.R

R --no-save --slave --args \
  -f $dbDir/nsfb_f_all_1_0.40.db 1 \
  -f $dbDir/nsfb_f_all_2_0.40.db 2 \
  -f $dbDir/nsfb_f_all_3_0.40.db 3 \
  --png $outDir/flood_retx.png \
  < fig_scripts/flood_retx.R

R --no-save --slave --args \
  -f $dbDir/nsfb_ub_all_1_0.40.db 1 \
  -f $dbDir/nsfb_ub_all_2_0.40.db 2 \
  -f $dbDir/nsfb_ub_all_3_0.40.db 3 \
  --png $outDir/ub_retx_0.png \
  < fig_scripts/ub_retx.R

R --no-save --slave --args \
  -f $dbDir/nsfb_ub_all_1_1.40.db 1 \
  -f $dbDir/nsfb_ub_all_2_1.40.db 2 \
  -f $dbDir/nsfb_ub_all_3_1.40.db 3 \
  --png $outDir/ub_retx_1.png \
  < fig_scripts/ub_retx.R

R --no-save --slave --args \
  -f $dbDir/nsfb_ub_all_1_0.40.db 0 \
  -f $dbDir/nsfb_ub_all_1_1.40.db 1 \
  -f $dbDir/nsfb_ub_all_1_3.40.db 3 \
  -f $dbDir/nsfb_ub_all_1_5.41.db 5 \
  --png $outDir/ub_bw.png \
  < fig_scripts/ub_bw.R

R --no-save --slave  --args \
  -nf data/0825/db/nsfb_f_all_1_0.40.db flood \
  -f data/0825/db/nsfb_ub_all_1_0.40.db ub_0 \
  -f data/0825/db/nsfb_ub_all_1_1.40.db ub_1 \
  -f data/0825/db/nsfb_ub_all_1_3.40.db ub_3 \
  -f data/0825/db/nsfb_ub_all_1_5.41.db ub_5 \
  --png fixed_settings/duty_cycle_improvement_cdf.png \
  < fig_scripts/duty_cycle_improvement_cdf.R

R --no-save --slave  --args \
  -f data/0825/db/nsfb_f_all_1_0.40.db flood \
  -f data/0825/db/nsfb_ub_all_1_0.40.db ub_0 \
  -f data/0825/db/nsfb_ub_all_1_1.40.db ub_1 \
  -f data/0825/db/nsfb_ub_all_1_3.40.db ub_3 \
  -f data/0825/db/nsfb_ub_all_1_5.41.db ub_5 \
  --png fixed_settings/duty_cycle_cdf.png \
  < fig_scripts/duty_cycle_cdf.R



