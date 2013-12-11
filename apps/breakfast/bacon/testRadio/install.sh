#!/bin/bash
if [ $# -lt 1 ]
then
cat 1>&2 <<EOF
Usage: $0 <dev>
Options: 
  -s        : node will be sender (default: receiver)
  -h        : turn on high-gain mode (default: off)
  -r        : turn on serial printf reporting. will also increase 
              interpacket interval to 32 ms. 
              (default: off)
  -c <0-255>: channel (default: 16)
  -p <0-3>  : set tx power level: 
                0 ~= -12 dbm 
                1 ~= -6 dbm
                2 ~= 0 dbm
                3 ~= 10 dbm
              (default: 2)
  -f <0,1>  : 0 = fec OFF, 1 = fec ON (default: fec OFF)
  -a <0,1>  : 0 = autocalibration off, 1= autocalibration on (default:
                  autocal on)
  -d <0,1>  : 0 = don't dump config at startup, 1= do (default 0)
EOF
  exit 1
fi

dev=$1
shift 1

isSender=FALSE
hgm=FALSE
report=FALSE
useLongIpi=FALSE
channel=0
power=2
dl=28
fecEnabled=1
autocal=1
dumpConfig=0

while [ $# -gt 0 ]
do
  case $1 in 
    -s)
      isSender=TRUE
      shift 1
    ;;
    -h)
      hgm=TRUE
      shift 1
    ;;
    -r)
      report=TRUE
      useLongIpi=TRUE
      shift 1
    ;;
    -c)
      shift 1
      channel=$1
      shift 1
    ;;
    -l)
      shift 1
      dl=$1
      shift 1
    ;;
    -p)
      shift 1
      power=$1
      shift 1
    ;;
    -f)
      shift 1
      fecEnabled=$1
      shift 1
    ;;
    -a)
      shift 1
      autocal=$1
      shift 1
    ;;
    -d)
      shift 1
      dumpConfig=$1
      shift 1
    ;;
    *)
      echo "unrecognized"
      shift 1
    ;;
  esac
done
set -x 
make bacon2 IS_SENDER=$isSender POWER_INDEX=$power HGM=$hgm \
  CHANNEL=$channel REPORT=$report USE_LONG_IPI=$useLongIpi \
  TOSH_DATA_LENGTH=$dl RF1A_FEC_ENABLED=$fecEnabled \
  RF1A_AUTOCAL=$autocal RF1A_DUMP_CONIFG=$dumpConfig\
  install bsl,$dev
