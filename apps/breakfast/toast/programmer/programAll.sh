#!/bin/bash
image=bin/asb.ihex
pwFile=bin/password.ihex
usingPython27=$(python --version 2>&1 | grep -c "2.7")
usingPython26=$(python --version 2>&1 | grep -c "2.6")
if [ $usingPython27 -eq 1 ]
then
  echo "Detected python 2.7"
  export PYTHONPATH=$PYTHONPATH:$(dirname $0)/python2.7
elif [ $usingPython26 -eq 1 ]
then
  echo "Detected python 2.6"
  export PYTHONPATH=$PYTHONPATH:$(dirname $0)/python2.6
else
  echo "Unrecognized python version $(python --version)" 1>&2
  echo " Only python 2.6 and 2.7 supported." 1>&2
  exit 1
fi

if [ $# -lt 1 ]
then 
  echo "No binary specified, defaulting to $image"
else
  image=$1
fi

if [ $# -eq 2 ]
then
  pwFile=$2
fi

echo "Using password file: $pwFile"
echo "Programming with binary: $image"
for dev in $(./motelist | awk '/USB/{print $2}')
do
  echo "Programming device at $dev"
  python msp430-bsl.py -D -D -D -D --invert-reset --invert-test \
    -c $dev -r -m 1 -I \
    -P $pwFile \
    -p $image
  if [ $? -eq 0 ]
  then
    echo "OK!"
  else
    echo "FAILED: Please check connections and retry." 1>&2
  fi
done
