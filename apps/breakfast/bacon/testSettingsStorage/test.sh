#!/bin/bash
export PYTHONPATH=$PYTHONPATH:${TOSROOT}/apps/breakfast/bacon/settingsStorage

python test.py $@
