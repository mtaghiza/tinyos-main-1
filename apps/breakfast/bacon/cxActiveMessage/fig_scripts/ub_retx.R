x<-read.csv('data/ub_retx.csv')
yl <- c(0,1.0)

plotFile=F
for (e in commandArgs()){
  if ( e == '--pdf' ){
    plotFile=T
    pdf('fig/ub_retx.pdf', width=9, height=6, title="ReTX in UB")
  }
  if ( e == '--png' ){
    plotFile=T
    png('fig/ub_retx.png', width=9, height=6, units="in", res=200)
  }
}
#CDF plot
xl <- c(0.0, 1.0)
firstPlot <- T
retxCols <- rainbow(length(unique(x$retx)))
retxVals <- sort(unique(x$retx))
medians<- c()
for (index in 1:length(retxVals)){
  retx <- retxVals[index]
  retxCol <- retxCols[index]

  vals <- x[x$retx==retx,]
  probs <- (1:dim(vals)[1])/dim(vals)[1]
  if (firstPlot){
    firstPlot <- F
    plot(x=c(0,sort(vals$prr_lr)), y=c(0, probs), ylab='Fraction', xlab='PRR',
      xlim=xl, ylim=yl, type='l', col=retxCol)
  }else{
    par(new=T)
    plot(x=c(0,sort(vals$prr_lr)), y=c(0,probs), ylab='', xlab='', xaxt='n', yaxt='n',
      xlim=xl, ylim=yl, type='l', col=retxCol)
  }
  medians <- c(medians, median(vals$prr_lr))
}
legend('topleft', legend=paste('retx:', retxVals, 'Med:', round(medians, 4)), 
  text.col=retxCols)
title("CDF of PRR in Unreliable Burst by #transmits")

if ( plotFile){
  g<-dev.off()
}


