args <- c()

for (e in commandArgs()[(which(commandArgs() == "--args")+1):length(commandArgs())]){
  ep = strsplit(e,"=",fixed=TRUE)
  name=ep[[1]][1]
  val=ep[[1]][2]

  if (name == 'forwardDelayDataFile'){
    forwardDelayDataFile <- val
  }
  if (name == 'outPrefix'){
    outPrefix <- val
  }
}

fdData <- read.csv(forwardDelayDataFile, col.names='Delay')

fd99Data <- fdData[fdData$Delay < quantile(fdData$Delay, 0.99),]
print("Mean")
print(mean(fd99Data))
print("sd")
print(sd(fd99Data))

fd99Data <- fd99Data - mean(fd99Data)
maxBin <- max(fd99Data)/0.25e-6
minBin <- min(fd99Data)/0.25e-6
pdf(paste(outPrefix, '.hist.pdf', sep=''))
hist(fd99Data*1e6, 
    breaks=0.25*((minBin-1):(maxBin+1)),
    xlab="Delay (uS)",
    main="Forwarding Delay (from SFD-SFD)")
garbage <- dev.off()
