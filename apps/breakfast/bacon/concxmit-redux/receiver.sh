#!/bin/bash
#receiver
#JH000357

ref=JH000357
dev=$(motelist | awk --assign ref=$ref '($1 == ref){print $2}')

make -f Makefile.receiver bacon2 install bsl,$dev \
  && picocom -b 115200 $dev | tee rx.log
