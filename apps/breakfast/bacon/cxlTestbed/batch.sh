#!/bin/bash
testDuration=$((60 * 60))

while true
do
  #power adjust
  for pa in 1
  do
    #tx power
    for txp in 0x2D 
    do
      #enable auto-sender
      for eas in 1
      do
        for efs in 0 1
        do
          #frames per slot
          for fps in 50
          do
            #data rate
            for dr in 0 1024 10240 30720 61440
            do
              #max cts miss threshold
              for mct in 4
              do
                #debug level stats-radio. DL_NONE disables radio state
                # change logging
                for dlsr in DL_INFO
                do
                  for slackScale in 1 
                  do
                    for md in 10 
                    do
                      rxs=$(($slackScale * 15))UL
                      txs=$(($slackScale * 44))UL
                      installTS=$(date +%s)
                      #welp, try it twice.
                      for i in $(seq 2)
                      do
                        ./testbed.sh eas $eas fps $fps dr $dr rp $txp lp $txp \
                          pa $pa mct $mct dlsr $dlsr gc 128 md $md\
                          efs $efs \
                          rxSlack $rxs txSlack $txs installTS $installTS
                        sleep 60
                      done
                      sleep $testDuration
                      pushd .
                      cd ~/tinyos-2.x/apps/Blink
                      ./burn map.all
                      sleep 60
                      popd
                    done
                  done
                done
              done
            done
          done
        done
      done
    done
  done
done
