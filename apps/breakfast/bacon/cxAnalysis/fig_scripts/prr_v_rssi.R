library(RSQLite)
library(ggplot2)
library(plyr)

fn <- ''
plotFile <- F
argc <- length(commandArgs())
argStart <- 1 + which (commandArgs() == '--args')
x <- c()

txPowers <- c()
xmin <- -100
xmax <- -20

selectQ <- "SELECT link.src, link.dest, link.txpower, link.avgRssi, link.avgLqi, prr,  tcs.c as srcCount, tcd.c as destCount 
  FROM link 
  JOIN (select src, txpower, count(*) c from TX GROUP BY src, txpower) tcs
  ON tcs.src = link.src and tcs.txpower = link.txpower
  JOIN (select src, txpower, count(*) c from TX GROUP BY src, txpower ) tcd
  ON tcd.src = link.dest and tcd.txpower = link.txpower" 

for (i in seq(argStart, argc-1)){
  opt <- commandArgs()[i]
  val <- commandArgs()[i+1]
  if ( opt == '--db'){
    fn <- val
    label <- commandArgs()[i+2]
    con <- dbConnect(dbDriver("SQLite"), dbname=fn)
    tmp <- dbGetQuery(con, selectQ)
    tmp$label <- label
    x <- rbind(x, tmp)
  }
  if ( opt == '--xmin'){
    xmin <- as.numeric(val)
  }
  if ( opt == '--xmax'){
    xmax <- as.numeric(val)
  }
  if ( opt == '--pdf' ){
    plotFile=T
    pdf(val, width=9, height=9, title="PRR vs. RSSI")
  }
  if ( opt == '--png' ){
    plotFile=T
    png(val, width=9, height=9, units="in", res=200)
  }
  if (opt == '--txp'){
    txPowers <- c(txPowers, as.numeric(val))
  }
}



x$txPowerF <- factor(x$txPower, levels=unique(x$txPower))
filtered <- c()
for (txp in txPowers){
  filtered <- rbind(filtered, x[x$txPower == txp,])
}

print(
  ggplot(filtered, aes(x=avgRssi, y=prr, color=txPowerF))
  + geom_point()
  + theme_bw()
  + scale_x_continuous(limits=c(-100, -40))
  + scale_y_continuous(limits=c(0, 1))
)

#maxSent <- max(x$srcCount)
#y <- x[x$srcCount > maxSent-200 & x$destCount > maxSent-200,]

# #plot(y$avgLqi, y$avgRssi)
# plot(y$avgRssi, y$prr, 
#   xlim=c(xmin, xmax), ylim=c(0, 1.0),
#   xlab="RSSI (dBm)",
#   ylab="PRR (0,1.0)"
#   )
# title("Single-transmitter Packet Reception Ratio vs. RSSI")

if(plotFile){
  g <- dev.off()
}
