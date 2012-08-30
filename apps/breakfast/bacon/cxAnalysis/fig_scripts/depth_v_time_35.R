#x <- read.csv('expansion/depth_v_time_35.csv')

fn <- ''
plotFile <- F
argc <- length(commandArgs())
argStart <- 1 + which (commandArgs() == '--args')

for (i in seq(argStart, argc-1)){
  opt <- commandArgs()[i]
  val <- commandArgs()[i+1]
  if ( opt == '-f'){
    fn <- val
  }
  if ( opt == '--pdf' ){
    plotFile=T
    pdf(val, width=9, height=6, title="Node 35 depth time series")
  }
  if ( opt == '--png' ){
    plotFile=T
    png(val, width=9, height=6, units="in", res=200)
  }
}

selectQ <- "SELECT ts, depth FROM rx_all WHERE src=35 AND dest = 0 ORDER by ts;"
library(RSQLite)
con <- dbConnect(dbDriver("SQLite"), dbname=fn)
rs <- dbSendQuery(con, selectQ);

x<- fetch(rs, n=-1)


plot(x=x$ts-min(x$ts), y=x$depth, type='o', ylab='Depth',
  xlab='Time(s)')
title('Trace of 35->Root Distance')

if ( plotFile){
  g<-dev.off()
}
