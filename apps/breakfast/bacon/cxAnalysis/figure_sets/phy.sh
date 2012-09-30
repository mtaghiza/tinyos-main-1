#!/bin/bash
goodSendersDb=data/cx/ber/good.db
badSendersDb=data/cx/ber/bad.db
conditionalPrrDb=data/cx/0913/db/conditionalPrr.db
outDir=output/phy

badSendersRandDb=data/cx/0917_prr_v_senders/db/ber.tests.berMaps.bad.1.1347936362.db
badSendersOnlyDb=data/cx/0917_prr_v_senders/db/ber.tests.berMaps.bad.nogood.db
#badSendersRandDb=data/cx/0917_prr_v_senders/db/ber.tests.berMaps.bad.2.1347958101.db
#goodSendersRandDb=data/cx/0917_prr_v_senders/db/ber.tests.berMaps.good.2.1347950857.db
#goodSendersRandDb=data/cx/0917_prr_v_senders/db/ber.tests.berMaps.good.3.1347972596.db


goodSendersRandDb=data/cx/0917_prr_v_senders/db/ber.tests.berMaps.good.1.1347929119.db
goodSendersOnlyDb=data/cx/0917_prr_v_senders/db/ber.tests.berMaps.good.nobad.db

set -x
R --no-save --slave --args \
  -f $goodSendersRandDb good+bad \
  -f $goodSendersOnlyDb good \
  -f $badSendersRandDb bad+good \
  -f $badSendersOnlyDb bad \
  --png $outDir/prr_v_senders_rand.png \
  < fig_scripts/prr_v_senders.R

R --no-save --slave --args \
  -f $goodSendersRandDb good+bad \
  -f $goodSendersOnlyDb good \
  -f $badSendersRandDb bad+good \
  -f $badSendersOnlyDb bad \
  --png $outDir/sender_capture.png \
  < fig_scripts/sender_capture.R

#non-randomized below
R --no-save --slave --args \
  -f $goodSendersDb good \
  -f $badSendersDb bad \
  --png $outDir/prr_v_senders.png \
  < fig_scripts/prr_v_senders.R

exit 0
R --no-save --slave --args \
  -f $conditionalPrrDb cond \
  --png $outDir/conditional_prr.png \
  < fig_scripts/conditional_prr.R

python fig_scripts/TestbedMap.py $conditionalPrrDb \
  --cond \
  --ref 56 \
  --outFile $outDir/spatial_cprr_far.png \
  > /dev/null

python fig_scripts/TestbedMap.py $conditionalPrrDb \
  --cond \
  --ref 8 \
  --outFile $outDir/spatial_cprr_close.png \
  > /dev/null


