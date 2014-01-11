#!/bin/bash
#
# Copyright (c) 2012 Johns Hopkins University.
# All rights reserved.
# 
# Permission to use, copy, modify, and distribute this software and its
# documentation for any purpose, without fee, and without written
# agreement is hereby granted, provided that the above copyright
# notice, the (updated) modification history and the author appear in
# all copies of this source code.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS  `AS IS'
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED  TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR  PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR  CONTRIBUTORS
# BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, LOSS OF USE,  DATA,
# OR PROFITS) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR  OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
# THE POSSIBILITY OF SUCH DAMAGE.
# 
# @author Doug Carlson <carlson@cs.jhu.edu>

if [ $# -lt 2 ]
then
  echo "Usage: $0 password nslufile"
  exit 1
fi

passw=$1
nsluFile=$2
set -x 

#copy over telos-monitor hotplug script
./copy-to-all.sh $nsluFile $passw ~/svn-private/tinyos-2.x/apps/Sensorbed/tinyos-telos-monitor_version2/src/11-telos-monitor /etc/hotplug.d/usb/11-telos-monitor

#copy the new proxy over
./copy-to-all.sh $nsluFile $passw ~/svn-private/tinyos-2.x/apps/Sensorbed/tinyos-telos-monitor_version2/src/proxy /usr/bin/proxy-telosb-bacon2

#remove old proxy sym link, replace with new one.
./exec-on-all.sh $nsluFile $passw "[ -h /usr/bin/proxy -a -f /usr/bin/proxy-telosb-bacon2 ] && rm /usr/bin/proxy && ln -s /usr/bin/proxy-telosb-bacon2 /usr/bin/proxy"

#copy the new bsl over
./copy-to-all.sh $nsluFile $passw ~/svn-private/tinyos-2.x/apps/Sensorbed/tinyos-telos-monitor_version2/cc430-cppbsl/src/cppbsl /usr/bin/bacon2-cppbsl

#move the old bsl out of the way
./exec-on-all.sh $nsluFile $passw "[ -f /usr/bin/cc430-cppbsl ] && mv /usr/bin/cc430-cppbsl /usr/bin/bacon1-cppbsl "
#remove old bsl sym link if it exists
./exec-on-all.sh $nsluFile $passw "[ -h /usr/bin/cc430-cppbsl ] && rm /usr/bin/cc430-cppbsl"
#new bsl sym link
./exec-on-all.sh $nsluFile $passw "[ -h /usr/bin/cc430-cppbsl ] || ln -s /usr/bin/bacon2-cppbsl /usr/bin/cc430-cppbsl"

#reboot it
#./exec-on-all.sh $nsluFile $passw "reboot"

