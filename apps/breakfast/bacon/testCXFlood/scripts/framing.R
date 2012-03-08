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
framingData$Offset <- framingData$Offset * 1000000

allOffsets <- rbind(framingData)
minOffset <- min(allOffsets$Offset)
maxOffset <- max(allOffsets$Offset)
q90 <- quantile(allOffsets$Offset, c(0.9))
q10 <- quantile(allOffsets$Offset, c(0.1))

plotData(framingData, "Frame Length", outPrefix, "full.framing",
  minOffset, maxOffset, "(uS)")
plotData(framingData, "Frame Length", outPrefix, "q80.framing", q10,
  q90, "(uS)")
