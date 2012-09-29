library(RSQLite)

#multiple bind parameters in dbGetQuery: looks like you need to do
#  some crazy stuff to make it work, so I'm being bad and just pasting
#  together a string
# see:
#   http://stackoverflow.com/questions/2186015/bind-variables-in-r-dbi

q0 <- "SELECT '"
q1 <- "' as label,
  sendCount,
 avg(rxOK) as prr,
 count(*) as cnt
FROM group_results
WHERE hopCount= "
q2<-" AND sendCount= "
q3<- " GROUP BY label, sendCount"

fn <- ''
plotFile <- F
argc <- length(commandArgs())
argStart <- 1 + which (commandArgs() == '--args')
raw <- c()
hc <- 2
for (i in seq(argStart, argc-1)){
  opt <- commandArgs()[i]
  val <- commandArgs()[i+1]
  if ( opt == '-f'){
    fn <- val
    sc <- commandArgs()[i+2]
    lbl <- commandArgs()[i+3]
    con <- dbConnect(dbDriver("SQLite"), dbname=fn)
    selectQ <- paste(q0, lbl, q1, hc, q2, sc, q3, sep='')
#    print(selectQ)
    raw <- rbind(raw, dbGetQuery(con, selectQ ))
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
raw <- raw[raw$cnt > 50,]

x <- c()
#x <- raw[raw$label == 'nocap',]
sep <- raw[raw$label != 'nocap',]
sep <- sep[as.numeric(sep$label) <= 17,]
sep <- sep[as.numeric(order(sep$label)),]
x <- rbind(x, sep)

#x <- raw[as.numeric(raw$label)!=23 & as.numeric(raw$label) != 33,]
x <- aggregate(prr~(sendCount*label),
  data=x, 
  FUN=mean)

firstPlot <- T
rCols <- rainbow(length(unique(x$label)))
labelVals <- sort(unique(as.numeric(x$label)))
xl <- c(1, max(x$sendCount))
yl <- c(0, 1.0)
for (index in 1:length(labelVals)){
  label <- labelVals[index]
  rCol <- rCols[index]
  vals <- x[x$label == label,]
  allVals <- raw[raw$label == label,]

  if (firstPlot){
    firstPlot <- F
    plot(x=vals$sendCount, y=vals$prr, ylab='PRR',
      xlab='Number of senders',
      xlim=xl, ylim=yl, type='o', col=rCol)
  }else{
    lines(x=vals$sendCount, y=vals$prr, col=rCol, type='o')
  }
  points(x=allVals$sendCount, y=allVals$prr, col=rCol, pch=1,
    cex=0.5)
} 
legend('bottomright', legend=paste(labelVals, ' dBm Capture' ), 
  text.col=rCols)
title("PRR v. Number of Senders by quality")

if ( plotFile){
  g<-dev.off()
}
