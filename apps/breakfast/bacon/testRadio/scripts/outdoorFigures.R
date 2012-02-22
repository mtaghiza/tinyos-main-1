
rssiDistance <- function(summaryFile, distanceLimits=NULL,
    rssiLimits=NULL, pdfName=NULL, pngName=NULL){
  rssi <- read.csv(summaryFile, sep=',', header=T)
  if (is.null(rssiLimits)){
    rssiLimits <- c(min(rssi$rssiMin) - 5, max(rssi$rssiMax) + 5)
  }
  if (is.null(distanceLimits)){
    distanceLimits <- c(min(rssi$distance) - 5, max(rssi$distance) + 5)
  }
  if (! is.null(pdfName)){
    pdf(pdfName)
  }
  if (! is.null(pngName)){
    pdf(pngName)
  }
  plot(-1000, -1000, xlim=distanceLimits, ylim=rssiLimits,
    xlab="Distance (m)", ylab="RSSI")
  lineCols=c('red', 'blue', 'green', 'black')
  #linePchs=c(1, 2, 4, 5)
  setups <- unique(rssi[,c('rxType', 'txType', 'power')])
  for (setupNum in seq_along(setups[,1])){
    setup <- setups[setupNum,]
    #get just the data for this particular arrangement
    setupData <- merge(rssi, setup)
    #sort by distance
    setupData <- setupData[order(setupData$distance),]
    #print(setup)
    #print(setupData)
    #print(lineCols[setup$rxType])
    #print(linePchs[setup$txType])
    lines(setupData$distance, setupData$rssiAvg,
      col=lineCols[setup$rxType + 1],
      pch=setup$txType+1, type='o')
    #TODO: bars for min/max
    #readline()
  }
  legend('bottomleft', title="Receiver", 
    legend=c("ANT", "FE", "SA", "Telos"), 
    col=c('red', 'blue', 'green', 'black'), lty=1)
  legend('bottomright', title="Sender", 
    legend=c("ANT", "FE", "Telos"), 
    pch=c(1,2,4))
  title("RSSI v. Distance (open field)")
  if (! is.null(pdfName)){
    garbage <- dev.off()
  }
  if (! is.null(pngName)){
    garbage <- dev.off()
  }
}
