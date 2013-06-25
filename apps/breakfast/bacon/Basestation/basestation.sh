#!/bin/bash
if [ $# -lt 1 ]
then 
  echo "Usage: $0 sleepInterval(seconds)" 1>&2
  exit 1
fi
sleepInterval=$1

while true
do
  python CXoalaDB.py serial@/dev/ttyUSB0:115200 61 60 0 
  sleep $sleepInterval
done
