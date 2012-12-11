#!/bin/bash

#find hamming distance from each byte to 0x00 and 0xff, report max

if [ $# -lt 1 ]
then
  exit 1
fi
f=$1

dos2unix $f

#21-end are the data bytes
awk 'BEGIN{
  symbols[0]=0
  symbols[0xff]=0xff
}
($0 ~ "RX"){
  print "RX", $3, $4, $5
}
/RX/{
  rssi=$3
  lqi=$4
  crcPassed=$5
  
  for(k=21; k<=NF; k++){
    minHD = 9
    for(ideal in symbols){
      b=$k
      hd = 0
      while ( xor(b, ideal)){
        if ( and(0x01, xor(b, ideal))){
          hd ++
        }
        b = rshift(b, 1)
        ideal = rshift(ideal, 1)
      }
      if (hd < minHD){
        minHD = hd
      }
    }
    print "HD",k-21, minHD
  }
}' $f


