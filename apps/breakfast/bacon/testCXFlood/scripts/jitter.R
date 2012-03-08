args <- c()

for (e in commandArgs()[(which(commandArgs() == "--args")+1):length(commandArgs())]){
  ep = strsplit(e,"=",fixed=TRUE)
  name=ep[[1]][1]
  val=ep[[1]][2]

  if (name == 'sfdDataFile'){
    sfdDataFile <- val
  }
  if (name == 'epiDataFile'){
    epiDataFile <- val
  }
  if (name == 'stxDataFile'){
    stxDataFile <- val
  }
  if (name == 'outPrefix'){
    outPrefix <- val
  }
}

plotData <- function(data, plotTitle, outPrePrefix, outPrefix, maxOffset){
  outPrefix <- paste(outPrePrefix, outPrefix, sep='.')
  data$Offset <- data$Offset*1000000
  pdf(paste(outPrefix, 'cdf', 'pdf', sep='.'))
  plot(sort(data$Offset), 
      (1:length(data$Offset))/length(data$Offset),
      type='l', 
      xlab="Offset (uS)", 
      xlim=c(0, 10),
      ylab="P (0-1.0)")
  title(plotTitle)
  garbage <- dev.off()
  
  pdf(paste(outPrefix, 'boxplot', 'pdf', sep='.'))
  boxplot(data$Offset, 
      ylim=c(0,5),
      ylab="Offset (uS)")
  
  title(plotTitle)
  garbage <- dev.off()
  
  pdf(paste(outPrefix, 'series', 'pdf', sep='.'))
  plot(data$Offset, 
      type='l', 
      xlab="Round", 
      ylim=c(0, 10),
      ylab="Offset (uS)")
  title(plotTitle)
  garbage <- dev.off()
}

sfdData <- read.csv(sfdDataFile, col.names='Offset')
epiData <- read.csv(epiDataFile, col.names='Offset')
stxData <- read.csv(stxDataFile, col.names='Offset')

allOffsets <- rbind(sfdData, epiData, stxData)
maxOffset <- max(allOffsets$Offset)
q90 <- quantile(allOffsets$Offset, c(0.9))

plotData(sfdData, "SFD Detected", outPrefix, "full.sfd", maxOffset)
plotData(epiData, "End Packet Interrupt", outPrefix, "full.ep", maxOffset)
plotData(stxData, "STX Strobe", outPrefix, "full.stx", maxOffset)

plotData(sfdData, "SFD Detected", outPrefix, "90.sfd", q90)
plotData(epiData, "End Packet Interrupt", outPrefix, "90.ep", q90)
plotData(stxData, "STX Strobe", outPrefix, "90.stx", q90)
