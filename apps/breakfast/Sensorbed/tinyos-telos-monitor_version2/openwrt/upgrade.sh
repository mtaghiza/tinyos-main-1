#!/bin/sh
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
#first, make backups of everything we're going to modify
./exec-on-all.sh $nsluFile $passw "cp /usr/bin/proxy /usr/bin/proxy-telosb ; cp /usr/bin/cppbsl /usr/bin/telosb-cppbsl"

#second, copy the new proxy over
./copy-to-all.sh $nsluFile $passw ~/svn-private/tinyos-2.x/apps/Sensorbed/tinyos-telos-monitor_version2/src/proxy /usr/bin/proxy-telosb-cc430

#third, copy the new cc430-cppbsl over
./copy-to-all.sh $nsluFile $passw ~/svn-private/tinyos-2.x/apps/Sensorbed/tinyos-telos-monitor_version2/cc430-cppbsl/src/cppbsl /usr/bin/cc430-cppbsl

#link proxy to the new version (without ruining anything)
./exec-on-all.sh $nsluFile $passw "[ -f /usr/bin/proxy-telosb ] && mv /usr/bin/proxy /usr/bin/proxy-original && ln -s /usr/bin/proxy-telosb-cc430 /usr/bin/proxy "

#reboot it
./exec-on-all.sh $nsluFile $passw "reboot"
