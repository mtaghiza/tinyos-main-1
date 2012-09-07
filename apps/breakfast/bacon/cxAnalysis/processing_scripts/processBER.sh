#!/bin/bash
#snifferId=1
log=$1

#tf=$(tempfile)
tf=tmp.txt

cat $log | awk  \
  '($3 == "S" ) && /^[0-9]+\.[0-9]+ [0-9]+ S [0-9A-F]+ -[0-9]+ [0-9]+ [0-9]+$/{print $0}' \
  > $tf

cat $tf | python processing_scripts/ber.py
