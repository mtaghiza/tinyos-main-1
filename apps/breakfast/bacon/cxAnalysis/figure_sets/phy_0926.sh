#!/bin/bash
outDir=output/phy_0926
sd=fig_scripts

#senders v. PRR, plus capture effect
# x axis: number of weak senders
# y axis: PRR
# series: with capture, without capture
goodNoCapture1=data/cx/0924/conditionalPRR_db/deterministic.map.200nocap.1.1348520404.db
goodNoCapture2=data/cx/0924/conditionalPRR_db/deterministic.map.200nocap.2.1348569320.db
goodNoCapture3=data/cx/0924/conditionalPRR_db/deterministic.map.200nocap.3.1348521694.db
goodNoCapture4=data/cx/0924/conditionalPRR_db/deterministic.map.200nocap.4.1348522337.db
goodNoCapture5=data/cx/0924/conditionalPRR_db/deterministic.map.200nocap.5.1348571251.db
goodNoCapture6=data/cx/0924/conditionalPRR_db/deterministic.map.200nocap.6.1348523625.db
goodNoCapture7=data/cx/0924/conditionalPRR_db/deterministic.map.200nocap.7.1348524269.db

cap_1_0x25=data/cx/capVSenders_threshold/conditionalPrr_db/map.200.capVSenders.1.0x25.1348613196.db
cap_2_0x25=data/cx/capVSenders_threshold/conditionalPrr_db/map.200.capVSenders.2.0x25.1348614140.db
cap_3_0x25=data/cx/capVSenders_threshold/conditionalPrr_db/map.200.capVSenders.3.0x25.1348615086.db
cap_4_0x25=data/cx/capVSenders_threshold/conditionalPrr_db/map.200.capVSenders.4.0x25.1348616030.db
cap_5_0x25=data/cx/capVSenders_threshold/conditionalPrr_db/map.200.capVSenders.5.0x25.1348616973.db
cap_6_0x25=data/cx/capVSenders_threshold/conditionalPrr_db/map.200.capVSenders.6.0x25.1348617917.db
cap_7_0x25=data/cx/capVSenders_threshold/conditionalPrr_db/map.200.capVSenders.7.0x25.1348618861.db


cap_1_0x2D=data/cx/capVSenders_threshold/conditionalPrr_db/map.200.capVSenders.1.0x2D.1348619805.db
cap_2_0x2D=data/cx/capVSenders_threshold/conditionalPrr_db/map.200.capVSenders.2.0x2D.1348620749.db
cap_3_0x2D=data/cx/capVSenders_threshold/conditionalPrr_db/map.200.capVSenders.3.0x2D.1348621692.db
cap_4_0x2D=data/cx/capVSenders_threshold/conditionalPrr_db/map.200.capVSenders.4.0x2D.1348622636.db
cap_5_0x2D=data/cx/capVSenders_threshold/conditionalPrr_db/map.200.capVSenders.5.0x2D.1348623579.db
cap_6_0x2D=data/cx/capVSenders_threshold/conditionalPrr_db/map.200.capVSenders.6.0x2D.1348624523.db
cap_7_0x2D=data/cx/capVSenders_threshold/conditionalPrr_db/map.200.capVSenders.7.0x2D.1348625467.db


cap_1_0x8D=data/cx/capVSenders_threshold/conditionalPrr_db/map.200.capVSenders.1.0x8D.1348626411.db
cap_2_0x8D=data/cx/capVSenders_threshold/conditionalPrr_db/map.200.capVSenders.2.0x8D.1348627354.db
cap_3_0x8D=data/cx/capVSenders_threshold/conditionalPrr_db/map.200.capVSenders.3.0x8D.1348628297.db
cap_5_0x8D=data/cx/capVSenders_threshold/conditionalPrr_db/map.200.capVSenders.5.0x8D.1348630185.db
cap_6_0x8D=data/cx/capVSenders_threshold/conditionalPrr_db/map.200.capVSenders.6.0x8D.1348631128.db
cap_7_0x8D=data/cx/capVSenders_threshold/conditionalPrr_db/map.200.capVSenders.7.0x8D.1348632072.db

set -x
R --no-save --slave --args\
  -f $goodNoCapture1 1 no_cap \
  -f $goodNoCapture2 2 no_cap \
  -f $goodNoCapture3 3 no_cap \
  -f $goodNoCapture4 4 no_cap \
  -f $goodNoCapture5 5 no_cap \
  -f $goodNoCapture6 6 no_cap \
  -f $goodNoCapture7 7 no_cap \
  -f $cap_1_0x25 2 cap_0x25\
  -f $cap_2_0x25 3 cap_0x25\
  -f $cap_3_0x25 4 cap_0x25\
  -f $cap_4_0x25 5 cap_0x25\
  -f $cap_5_0x25 6 cap_0x25\
  -f $cap_6_0x25 7 cap_0x25\
  -f $cap_7_0x25 8 cap_0x25\
  -f $cap_1_0x2D 2 cap_0x2D\
  -f $cap_2_0x2D 3 cap_0x2D\
  -f $cap_3_0x2D 4 cap_0x2D\
  -f $cap_4_0x2D 5 cap_0x2D\
  -f $cap_5_0x2D 6 cap_0x2D\
  -f $cap_6_0x2D 7 cap_0x2D\
  -f $cap_7_0x2D 8 cap_0x2D\
  -f $cap_1_0x8D 2 cap_0x8D\
  -f $cap_2_0x8D 3 cap_0x8D\
  -f $cap_3_0x8D 4 cap_0x8D\
  -f $cap_5_0x8D 6 cap_0x8D\
  -f $cap_6_0x8D 7 cap_0x8D\
  -f $cap_7_0x8D 8 cap_0x8D\
  --png $outDir/prr_v_senders.png \
  < $sd/prr_v_senders.R

#senders v. RSSI
# x axis: number of senders, +individual (@0)
# boxplot 
