#!/bin/bash

if [ $# -gt 0 ]
then
  cat $@ | python $(dirname $0)/prr.py 
else
  echo "Usage: $0 file [file...]" 1>&2
  echo "  Note that all files are assumed to be from the same test run."  1>&2
fi
