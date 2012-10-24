#!/bin/bash
shortDuration=$((60*60))
longDuration=$((2 *60 *60))

txp=0x8D
i=0
midRateOptions='targetIpi 61440UL queueThreshold 10'
burstOptions="senderDest 0 requestAck 0"
while [ true ]
do
  for rate in mid
  do
    if [ "$rate" == "low" ]
    then
      rateOptions=$lowRateOptions
      testDuration=$longDuration
    elif [ "$rate" == "high" ] 
    then
      rateOptions=$highRateOptions
      testDuration=$shortDuration
    elif [ "$rate" == "mid" ]
    then
      rateOptions=$midRateOptions
      testDuration=$shortDuration
    else
      echo "unknown rate $rate"
      exit 1
    fi

    i=$(( $i + 1))
    for cxForwarderSelection in 2 0
    do
      for thresh in -100
      do
        for fec in 1 0
        do
          for bufferWidth in 0 2
          do
            ./installTestbed.sh \
              testLabel burst.thresh.$thresh.fec.${fec}.bw.${bufferWidth}.sel.${cxForwarderSelection}.$i \
              txp $txp \
              receiverMap map.none \
              senderMap map.nonroot\
              rootMap map.0 \
              maxDepth 10 \
              fps 40 \
              rssiThreshold $thresh\
              fecEnabled $fec\
              $burstOptions \
              $rateOptions \
              bufferWidth $bufferWidth \
              cxForwarderSelection $cxForwarderSelection
            sleep $testDuration
    
            ./installTestbed.sh \
              testLabel flood.thresh.$thresh.fec.${fec}.$i.bw.-1.sel.-1.$i \
              txp $txp \
              receiverMap map.none \
              senderMap map.nonroot\
              rootMap map.0 \
              maxDepth 10 \
              fps 40 \
              rssiThreshold $thresh\
              fecEnabled $fec\
              $floodOptions \
              $rateOptions
            sleep $testDuration
          done
        done
      done
    done
  done
done
