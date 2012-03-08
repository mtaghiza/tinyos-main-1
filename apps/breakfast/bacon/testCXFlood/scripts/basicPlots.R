plotData <- function(data, plotTitle, outPrePrefix, outPrefix, minOffset, maxOffset, units){
  outPrefix <- paste(outPrePrefix, outPrefix, sep='.')
  pdf(paste(outPrefix, 'cdf', 'pdf', sep='.'))
  plot(sort(data$Offset), 
      (1:length(data$Offset))/length(data$Offset),
      type='l', 
      xlab=paste("Offset", units), 
      xlim=c(minOffset, maxOffset),
      ylab="P (0-1.0)")
  title(plotTitle)
  garbage <- dev.off()
  
  pdf(paste(outPrefix, 'boxplot', 'pdf', sep='.'))
  boxplot(data$Offset, 
      ylim=c(minOffset,maxOffset),
      xlab=paste("Offset", units)) 
  
  title(plotTitle)
  garbage <- dev.off()
  
  pdf(paste(outPrefix, 'series', 'pdf', sep='.'))
  plot(data$Offset, 
      type='l', 
      xlab="Round", 
      ylim=c(minOffset, maxOffset),
      ylab=paste("Offset", units))
  title(plotTitle)
  garbage <- dev.off()
}

