x<-read.csv('expansion/ub_bw.csv')
yl <- c(0,1.0)

plotFile=F
for (e in commandArgs()){
  if ( e == '--pdf' ){
    plotFile=T
    pdf('fig/ub_bw.pdf', width=9, height=6, title="Buffer width in UB")
  }
  if ( e == '--png' ){
    plotFile=T
    png('fig/ub_bw.png', width=9, height=6, units="in", res=200)
  }
}
#CDF plot
xl <- c(0.0, 1.0)
firstPlot <- T
bwCols <- rainbow(length(unique(x$bw)))
bwVals <- sort(unique(x$bw))
medians<- c()
for (index in 1:length(bwVals)){
  bw <- bwVals[index]
  bwCol <- bwCols[index]

  vals <- x[x$bw==bw,]
  probs <- (1:dim(vals)[1])/dim(vals)[1]
  if (firstPlot){
    firstPlot <- F
    plot(x=c(0,sort(vals$prr_lr)), y=c(0, probs), ylab='Fraction', xlab='PRR',
      xlim=xl, ylim=yl, type='l', col=bwCol)
  }else{
    par(new=T)
    plot(x=c(0,sort(vals$prr_lr)), y=c(0,probs), ylab='', xlab='', xaxt='n', yaxt='n',
      xlim=xl, ylim=yl, type='l', col=bwCol)
  }
  medians <- c(medians, median(vals$prr_lr))
}
legend('topleft', legend=paste('BW:', bwVals, 'Med:', round(medians, 4)), 
  text.col=bwCols)
title("CDF of PRR in Unreliable Burst by buffer width")

if ( plotFile){
  g<-dev.off()
}
