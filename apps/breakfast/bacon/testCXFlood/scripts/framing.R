args <- c()

for (e in commandArgs()[(which(commandArgs() == "--args")+1):length(commandArgs())]){
  ep = strsplit(e,"=",fixed=TRUE)
  name=ep[[1]][1]
  val=ep[[1]][2]

  if (name == 'framingDataFile'){
    framingDataFile <- val
  }
  if (name == 'outPrefix'){
    outPrefix <- val
  }
}

source('scripts/basicPlots.R')

framingData <- read.csv(framingDataFile, col.names='Offset')

framing99Data <- framingData[framingData$Offset < quantile(framingData$Offset, 0.99),]
print("Mean")
print(mean(framing99Data))
print("sd")
print(sd(framing99Data))

framingData$Offset <- framingData$Offset * 1000000
framingData$Offset <- framingData$Offset - mean(framingData$Offset)

allOffsets <- rbind(framingData)
minOffset <- min(allOffsets$Offset)
maxOffset <- max(allOffsets$Offset)
q90 <- quantile(allOffsets$Offset, c(0.9))
q10 <- quantile(allOffsets$Offset, c(0.1))

plotData(framingData, "Frame Length w.r.t Mean", outPrefix, "full.framing",
  minOffset, maxOffset, "(uS)")
plotData(framingData, "Frame Length w.r.t Mean", outPrefix, "q80.framing", q10,
  q90, "(uS)")

