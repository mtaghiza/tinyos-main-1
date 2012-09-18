library(RSQLite)

#multiple bind parameters in dbGetQuery: looks like you need to do
#  some crazy stuff to make it work, so I'm being bad and just pasting
#  together a string
# see:
#   http://stackoverflow.com/questions/2186015/bind-variables-in-r-dbi

q0 <- "SELECT '"
q1 <- "' as label,
  sendCount,
 avg(rxOK) as prr 
FROM group_results
WHERE hopCount= "
q2<- " GROUP BY label, sendCount"

fn <- ''
plotFile <- F
argc <- length(commandArgs())
argStart <- 1 + which (commandArgs() == '--args')
x <- c()
hc <- 2
for (i in seq(argStart, argc-1)){
  opt <- commandArgs()[i]
  val <- commandArgs()[i+1]
  if ( opt == '-f'){
    fn <- val
    lbl <- commandArgs()[i+2]
    con <- dbConnect(dbDriver("SQLite"), dbname=fn)
    selectQ <- paste(q0, lbl, q1, hc, q2)
    x <- rbind(x, dbGetQuery(con, selectQ ))
  }
  if ( opt == '--pdf' ){
    plotFile=T
    pdf(val, width=9, height=9, title="PRR v. Senders")
  }
  if ( opt == '--png' ){
    plotFile=T
    png(val, width=9, height=9, units="in", res=200)
  }
}

firstPlot <- T
rCols <- rainbow(length(unique(x$label)))
labelVals <- sort(unique(x$label))
xl <- c(1, max(x$sendCount))
yl <- c(0, 1.0)
for (index in 1:length(labelVals)){
  label <- labelVals[index]
  rCol <- rCols[index]
  vals <- x[x$label == label,]

  if (firstPlot){
    firstPlot <- F
    plot(x=vals$sendCount, y=vals$prr, ylab='PRR',
      xlab='Number of senders',
      xlim=xl, ylim=yl, type='l', col=rCol)
  }else{
    par(new=T)
    lines(x=vals$sendCount, y=vals$prr, col=rCol)
  }
} 
legend('right', legend=paste('Label:', labelVals ), 
  text.col=rCols)
title("PRR v. Number of Senders by quality")

if ( plotFile){
  g<-dev.off()
}
