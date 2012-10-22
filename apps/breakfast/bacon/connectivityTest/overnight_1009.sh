#!/bin/bash
./installer.sh 0x2D
ssh carlson@mojo './connectivityTest.sh 2>&1 | tee -a 1009.log'

./installer.sh 0x8D
ssh carlson@mojo './connectivityTest.sh 2>&1 | tee -a 1009.log'

./installer.sh 0x25
ssh carlson@mojo './connectivityTest.sh 2>&1 | tee -a 1009.log'
