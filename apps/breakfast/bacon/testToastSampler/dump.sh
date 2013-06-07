#!/bin/bash
export PYTHONPATH=${PYTHONPATH}:../testAutoPush/.
python $(dirname $0)/dump.py $@
