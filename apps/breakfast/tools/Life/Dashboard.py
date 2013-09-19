#!/usr/bin/env python
import subprocess
import datetime
import os

if __name__ == "__main__":
    logDir ='logs'
    if not os.path.isdir(logDir):
        os.mkdir(logDir)
    f = open(os.path.join(logDir, "%s.log"%(datetime.datetime.now())), 'w')
    subprocess.call("python DashboardInternal.py", stdout=f,
      stderr=subprocess.STDOUT, shell=True)
