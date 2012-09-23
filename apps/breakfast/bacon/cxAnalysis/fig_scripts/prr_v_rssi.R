library(RSQLite)

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
  }
  if ( opt == '--pdf' ){
    plotFile=T
    pdf(val, width=9, height=9, title="PRR vs. RSSI")
  }
  if ( opt == '--png' ){
    plotFile=T
    png(val, width=9, height=9, units="in", res=200)
  }
}

selectQ <- "SELECT link.src, link.dest, link.avgRssi, link.avgLqi, prr,  tcs.c as srcCount, tcd.c as destCount FROM link 
  JOIN (select src, count(*) c from TX GROUP BY src) tcs
  ON tcs.src = link.src
  JOIN (select src, count(*) c from TX GROUP BY src ) tcd
  ON tcd.src = link.dest"
con <- dbConnect(dbDriver("SQLite"), dbname=fn)
x <- dbGetQuery(con, selectQ)

maxSent <- max(x$srcCount)
y <- x[x$srcCount > maxSent-200 & x$destCount > maxSent-200,]
plot(y$avgRssi, y$prr)

if(plotFile){
  g <- dev.off()
}
