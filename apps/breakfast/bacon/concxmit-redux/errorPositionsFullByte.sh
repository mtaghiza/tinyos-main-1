#!/bin/bash
if [ $# -lt 1 ]
then
  exit 1
fi
f=$1

dos2unix $f

#21-end are the data bytes
awk '($0 ~ "RX"){
  print "RX", $3, $4, $5
}
/RX/{
  rssi=$3
  lqi=$4
  crcPassed=$5
  
  for(k=21; k<=NF; k++){
    b = $k
    if (k % 2){
      ideal= 0x00
    }else{
      ideal = 0xff
    }
    bitIndex = 7
    while ( xor(b, ideal)){
      if ( and(0x01, xor(b, ideal))){
        printf("EP %d\n", (k-21)*8 + bitIndex);
      }
      b = rshift(b, 1)
      ideal = rshift(ideal, 1)
      bitIndex -- 
    }
  }
}' $f


