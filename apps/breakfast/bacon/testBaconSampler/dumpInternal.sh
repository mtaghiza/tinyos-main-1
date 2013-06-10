#!/bin/bash
export PYTHONPATH=${PYTHONPATH}:../testToastSampler/.:../testAutoPush/.
python $(dirname $0)/dumpInternal.py $@
