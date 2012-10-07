library(RSQLite)
selectQ <- "SELECT
  ? as label,
  node,
  dc
FROM duty_cycle
WHERE dc is not NULL"

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
    lbl <- commandArgs()[i+2]
    con <- dbConnect(dbDriver("SQLite"), dbname=fn)
    x <- rbind(x, dbGetQuery(con, selectQ, lbl))
  }
  if ( opt == '--pdf' ){
    plotFile=T
    pdf(val, width=9, height=6, title="Duty Cycle CDF")
  }
  if ( opt == '--png' ){
    plotFile=T
    png(val, width=9, height=6, units="in", res=200)
  }
}

#CDF plot
yl <- c(0,1.0)
xl <- c(0, 0.2)
firstPlot <- T
rCols <- rainbow(length(unique(x$label)))
labelVals <- sort(unique(x$label))
medians<-c()
means <- c()
for (index in 1:length(labelVals)){
  label <- labelVals[index]
  rCol <- rCols[index]

  vals <- x[x$label == label,]
  probs <- (1:dim(vals)[1])/dim(vals)[1]
  if (firstPlot){
    firstPlot <- F
    plot(x=c(0,sort(vals$dc),1), y=c(0, probs,1), ylab='Fraction',
      xlab='Duty Cycle',
      xlim=xl, ylim=yl, type='l', col=rCol)
  }else{
    par(new=T)
    plot(x=c(0,sort(vals$dc),1), y=c(0,probs, 1), ylab='', xlab='', xaxt='n', yaxt='n',
      xlim=xl, ylim=yl, type='l', col=rCol)
  }
    
  medians <- c(medians, median(vals$dc))
  means <- c(means, mean(vals$dc))
}
lines(c(0.0043, 0.0043), c(0,1), lty=3)
lines(c(0.1, 0.1), c(0,1), lty=2)
legend('bottomright', legend=paste('Label:', labelVals, 'Med:',
  round(medians, 4), 'Mean:', round(means, 4)), 
  text.col=rCols)
title("Duty Cycle")

if ( plotFile){
  g<-dev.off()
}
