#!/bin/bash
set -x
while [ $# -gt 0 ]
do
  awk -F '=' '/^P_/{print $2}' $1 > $1.csv
  shift 1
done
