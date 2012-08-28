#!/bin/bash
if [ $# -lt 1 ]
then
  echo "usage: $0 <id>" 1>&2
  exit 1
fi
id=$1
if [ "$id" == "0" ]
then
  ref=JH000355
else
  ref=JH000354
fi
dev=$(motelist | awk --assign ref=$ref '($1==ref){print $2}')
make bacon2 AUTOSEND=0 install,$id bsl,$dev
