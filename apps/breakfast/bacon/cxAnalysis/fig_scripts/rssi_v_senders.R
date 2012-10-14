library(RSQLite)

selectQ <- "SELECT rssi, sendCount, crcPassed 
FROM sniffs 
JOIN numSenders ON 
  sniffs.cycle = numSenders.cycle 
  AND sniffs.sn = numSenders.sn 
  AND sniffs.hopCount=numSenders.hopcount 
WHERE sniffs.hopCount=2"

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
    con <- dbConnect(dbDriver("SQLite"), dbname=fn)
    x <- dbGetQuery(con, selectQ)
  }
  if ( opt == '--pdf' ){
    plotFile=T
    pdf(val, width=9, height=9, title="RSSI v. Num Senders")
  }
  if ( opt == '--png' ){
    plotFile=T
    png(val, width=9, height=9, units="in", res=200)
  }
}

boxplot(rssi~sendCount, 
  data=x, 
  xlab="Number of Senders", 
  ylab="RSSI")
title("RSSI v. Number of Senders")

if (plotFile){
  g <- dev.off()
}
