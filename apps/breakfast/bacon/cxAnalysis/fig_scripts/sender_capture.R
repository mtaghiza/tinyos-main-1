library(RSQLite)

#multiple bind parameters in dbGetQuery: looks like you need to do
#  some crazy stuff to make it work, so I'm being bad and just pasting
#  together a string
# see:
#   http://stackoverflow.com/questions/2186015/bind-variables-in-r-dbi

# selectQ1 <- "SELECT ?
#   as label,
#   link.src as src, 
#   link.avgRssi as rssi, 
#   link.avgLqi as lqi, 
#   p.prr as prr
# FROM link 
# JOIN (
#   SELECT * from prr_v_node 
#   WHERE hopCount=2 and sendCount=1 and involved=1
# ) p
# ON link.src = p.src
# ORDER BY link.avgRssi"

selectQ2 <- "SELECT ?
  as label,
  link.src as src, 
  link.avgRssi as rssi, 
  link.avgLqi as lqi, 
  p.prr as prr
FROM link 
JOIN (
  SELECT * from prr_v_node 
  WHERE hopCount=2 and sendCount=2 and involved=1
) p
ON link.src = p.src
ORDER BY link.avgRssi"

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
#    x <- rbind(x, dbGetQuery(con, selectQ1, paste(lbl, 'single') ))
    x <- rbind(x, dbGetQuery(con, selectQ2, paste(lbl, 'multi') ))
  }
  if ( opt == '--pdf' ){
    plotFile=T
    pdf(val, width=9, height=9, title="Capture effect")
  }
  if ( opt == '--png' ){
    plotFile=T
    png(val, width=9, height=9, units="in", res=200)
  }
}

firstPlot <- T
rCols <- rainbow(length(unique(x$label)))
labelVals <- sort(unique(x$label))
xl <- c(-95, -60)
yl <- c(0, 1.0)
for (index in 1:length(labelVals)){
  label <- labelVals[index]
  rCol <- rCols[index]
  vals <- x[x$label == label,]

  if (firstPlot){
    firstPlot <- F
    plot(x=vals$rssi, y=vals$prr, ylab='PRR',
      xlab='RSSI',
      xlim=xl, ylim=yl, type='o', col=rCol)
  }else{
    lines(x=vals$rssi, y=vals$prr, col=rCol, type='o')
  }
} 
legend('right', legend=paste('Label:', labelVals ), 
  text.col=rCols)
title("PRR v. Single sender RSSI")

if ( plotFile){
  g<-dev.off()
}

