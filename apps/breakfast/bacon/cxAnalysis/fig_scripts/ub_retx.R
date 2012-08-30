library(RSQLite)
selectQ <- "SELECT 
  a.src,
  a.dest,
  ? as retx,
  a.prr as prr_lr
FROM prr_clean a
WHERE a.dest=0 AND a.pr=1"

fn <- ''
plotFile <- F
argc <- length(commandArgs())
argStart <- 1 + which (commandArgs() == '--args')
x <- c()

for (i in seq(argStart, argc-1)){
  opt <- commandArgs()[i]
  val <- commandArgs()[i+1]
  if ( opt == '-f'){
    fn <- val
    retx <- as.integer(commandArgs()[i+2])
    con <- dbConnect(dbDriver("SQLite"), dbname=fn)
    x <- rbind(x, dbGetQuery(con, selectQ, retx))
  }
  if ( opt == '--pdf' ){
    plotFile=T
    pdf(val, width=9, height=6, title="Burst PRR v. ReTX CDF")
  }
  if ( opt == '--png' ){
    plotFile=T
    png(val, width=9, height=6, units="in", res=200)
  }
}


#CDF plot
yl <- c(0,1.0)
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


