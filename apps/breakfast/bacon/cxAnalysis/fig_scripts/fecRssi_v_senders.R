plotFile <- F
argc <- length(commandArgs())
argStart <- 1 + which (commandArgs() == '--args')
x <- c()
library(plyr)
library(ggplot2)
library(RSQLite)

plotType <- 'RSSI'
sr <- 125
selectQ <- 'SELECT rssi,lqi from raw where cnt=2 and lqi<=50'
checkQ <- 'SELECT count(*) from ber'
pw <- 8
ph <- 4
for (i in seq(argStart, argc-1)){
  opt <- commandArgs()[i]
  val <- commandArgs()[i+1]
  if (opt == '--aspect'){
    if (val == 'square'){
      pw <- 4
      ph <- 4
    }
  }
  if ( opt == '--db'){
    fn <- val
    con <- dbConnect(dbDriver("SQLite"), dbname=fn)
    sc <- as.numeric(commandArgs()[i+2])
    symbolRate <- as.numeric(commandArgs()[i+3])
    fecOn <- as.numeric(commandArgs()[i+4])
    captureMargin <- as.numeric(commandArgs()[i+5])
    highPresent <- as.numeric(commandArgs()[i+6])

    cnt <- dbGetQuery(con, checkQ)
    if (cnt[1] >0){
      tmp <- dbGetQuery(con, selectQ )
      tmp$fn <- fn
      tmp$sc <- sc
      tmp$symbolRate <- symbolRate
      tmp$fecOn <- fecOn
      tmp$captureMargin <- captureMargin
      tmp$highPresent <- highPresent
      x <- rbind(x, tmp)
    }
  }
  if ( opt == '--pdf' ){
    plotFile=T
    pdf(val, width=pw, height=ph, title=paste(plotType, "v. Senders"))
  }
  if ( opt == '--png' ){
    plotFile=T
    png(val, width=pw, height=ph, units="in", res=200)
  }
  if ( opt == '--plotType'){
    plotType <- val
  }
  if (opt == '--sr'){
    sr <- as.numeric(val)
  }
}
x$fecOn <- factor(x$fecOn)
x$captureMargin <- factor(x$captureMargin)

boxplot(rssi~sc,
  data=x,
  xlab="Number of Senders",
  ylab="RSSI",
  outpch='.',
  whisklty=1)
title("RSSI v. Number of Senders")

if (plotFile){
  g <- dev.off()
}
