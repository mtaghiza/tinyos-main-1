#!/bin/bash
if [ $# -lt 2 ]
then
  exit 1
fi
installLog=$1
tbLog=$2

grep 'SETUP' $installLog | grep -v 'echo' | cat - $tbLog | sort -n -k 1
