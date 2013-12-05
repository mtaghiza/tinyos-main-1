#!/usr/bin/env python
import subprocess
import datetime
import os

if __name__ == "__main__":
    logDir ='logs'
    if not os.path.isdir(logDir):
        os.mkdir(logDir)
        
    now = datetime.datetime.now()
    now_str = now.strftime("%Y%m%dT%H%M%S")
    
    f = open(os.path.join(logDir, "%s.log"%now_str), 'w')
    subprocess.call("python DashboardInternal.py", stdout=f,
      stderr=subprocess.STDOUT, shell=True)
