x<-read.csv('data/flood_retx.csv')
yl <- c(0,1.0)

plotFile=F
for (e in commandArgs()){
  if ( e == '--pdf' ){
    plotFile=T
    pdf('fig/flood_retx.pdf', width=9, height=6, title="Flood W. ReTX")
  }
  if ( e == '--png' ){
    plotFile=T
    png('fig/flood_retx.png', width=9, height=6, units="in", res=200)
  }
}
#CDF plot
xl <- c(0.8, 1.0)
firstPlot <- T
rCols <- rainbow(length(unique(x$retx)))
retxVals <- sort(unique(x$retx))
lrMedians<-c()
rlMedians<-c()
for (index in 1:length(retxVals)){
  retx <- retxVals[index]
  rCol <- rCols[index]

  vals <- x[x$retx==retx,]
  probs <- (1:dim(vals)[1])/dim(vals)[1]
  if (firstPlot){
    firstPlot <- F
    plot(x=c(0,sort(vals$prr_lr)), y=c(0, probs), ylab='Fraction', xlab='PRR',
      xlim=xl, ylim=yl, type='l', col=rCol)
  }else{
    par(new=T)
    plot(x=c(0,sort(vals$prr_lr)), y=c(0,probs), ylab='', xlab='', xaxt='n', yaxt='n',
      xlim=xl, ylim=yl, type='l', col=rCol)
  }
  par(new=T)
  plot(x=c(0,sort(vals$prr_rl)), y=c(0,probs), ylab='', xlab='', xaxt='n', yaxt='n',
    xlim=xl, ylim=yl, type='l', col=rCol, lty=2)
    
  lrMedians <- c(lrMedians, median(vals$prr_lr))
  rlMedians <- c(rlMedians, median(vals$prr_rl))
}
legend('topleft', legend=paste('Transmits:', retxVals, 'Med LR:',
  round(lrMedians, 4), 'Med RL:', round(rlMedians, 4)), 
  text.col=rCols)
legend('left', legend=c('Leaf->Root', 'Root->Leaf'), lty=c(1,2),
  horiz=F)
title("Flood w. Multiple transmissions")


#comparison plot
##ordering:
##  re-order each set by nodeId
##  master order: PRR ascending at 1 tx
#xl <- c(0, max(x$src))
#t <- x[x$retx==1,]
#t <- t[order(t$src)]
#o <- order(t$prr_lr)
#HEY: remove links missing from some runs
#firstPlot <- T
#for (retx in sort(unique(x$retx))){
#  t <- x[x$retx == retx,]
#  t <- t[o,]
#  if (firstPlot){
#    firstPlot <- F
#    plot(x=t$src, y=t$prr_lr, ylab='PRR', xlab='Node Id')
#  }else{
#    par(new=T)
#    plot(x=t$src, y=t$prr_lr)
#  }
#}

if ( plotFile){
  g<-dev.off()
}
