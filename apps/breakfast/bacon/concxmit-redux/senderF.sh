#!/bin/bash
#fixed sender: #1
#JH000305

ref=JH000305
dev=$(motelist | awk --assign ref=$ref '($1 == ref){print $2}')

#0x25, fixed -20 dB attenuation: -22.5 dBm
#0x25, fixed -40 dB attenuation: -44 dBm
#0x8D, fixed -40 dB attenuation: -33 dBm
make -f Makefile.sender bacon2 install bsl,$dev \
  SENDER_1=1 TX_POWER_1=0x8D\
  RANDOMIZE_PACKET=0\
  && picocom -b 115200 $dev | tee txf.log
