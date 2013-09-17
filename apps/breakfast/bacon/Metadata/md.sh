#!/bin/bash
PYTHONPATH=$PYTHONPATH:../../tools/Life/

if [ $# -eq 0 ]
then
  echo "Assume default settings"
  python md-cli.py serial@/dev/ttyUSB0:115200 1 --auto scan 1
else
  python md-cli.py $@
fi
