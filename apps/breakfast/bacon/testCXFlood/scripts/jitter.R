args <- c()

for (e in commandArgs()[(which(commandArgs() == "--args")+1):length(commandArgs())]){
  ep = strsplit(e,"=",fixed=TRUE)
  name=ep[[1]][1]
  val=ep[[1]][2]

  if (name == 'sfdDataFile'){
    sfdDataFile <- val
  }
  if (name == 'sfdDelayDataFile'){
    sfdDelayDataFile <- val
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

source('scripts/basicPlots.R')

sfdData <- read.csv(sfdDataFile, col.names='Offset')
epiData <- read.csv(epiDataFile, col.names='Offset')
stxData <- read.csv(stxDataFile, col.names='Offset')

sfdData$Offset <- sfdData$Offset*1000000
epiData$Offset <- epiData$Offset*1000000
stxData$Offset <- stxData$Offset*1000000

allOffsets <- rbind(sfdData, epiData, stxData)
maxOffset <- max(allOffsets$Offset)
q99 <- quantile(allOffsets$Offset, c(0.99))
minOffset <- 0

#  plotData(sfdData, "SFD Detected", outPrefix, "full.sfd", minOffset,
#  maxOffset, "(uS)")
#  plotData(epiData, "End Packet Interrupt", outPrefix, "full.ep",
#  minOffset, maxOffset, "(uS)")
#  plotData(stxData, "STX Strobe", outPrefix, "full.stx", minOffset,
#  maxOffset, "(uS)")
#  
#  plotData(sfdData, "SFD Detected", outPrefix, "99.sfd", minOffset, q99,
#  "(uS)")
#  plotData(epiData, "End Packet Interrupt", outPrefix, "99.ep",
#  minOffset, q99, "(uS)")
#  plotData(stxData, "STX Strobe", outPrefix, "99.stx", minOffset, q99,
#  "(uS)")
  
origSfdData <- read.csv(sfdDataFile, col.names='Offset')
#origSfdData <- sfdData
sfd99Data <- origSfdData[origSfdData$Offset < quantile(origSfdData$Offset, 0.99),]
#print("Summary (SFD) to 99th percentile")
#print(summary(sfd99Data))
print("Mean")
print(mean(sfd99Data))
print("sd")
print(sd(sfd99Data))

pdf(paste(outPrefix, '.hist.pdf', sep=''))
maxBin <- max(sfd99Data)/0.25e-6
hist(sfd99Data*1e6, 
    breaks=0.25*(0:(maxBin+1)),
    xlab="Offset (uS)",
    main="Forwarder SFD offset")
garbage <- dev.off()
