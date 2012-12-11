#!/bin/bash
#var sender: #2
#JH000300
ref=JH000300
dev=$(motelist | awk --assign ref=$ref '($1 == ref){print $2}')

#TODO: switch to sender_1=0, tx_power_2=?
#0x25 middle resistance: -43
#0x8D middle resistance: -33
make -f Makefile.sender bacon2 install bsl,$dev \
  SENDER_1=1 TX_POWER_1=0x8D\
  RANDOMIZE_PACKET=1\
  MARK_LOCATION=0xff\
  && picocom -b 115200 $dev | tee txv.log
