plotFile <- F
argc <- length(commandArgs())
argStart <- 1 + which (commandArgs() == '--args')
library(plyr)
library(ggplot2)
library(RSQLite)

selectQRL <- "SELECT 
dest as node, prr
FROM prr_clean a
WHERE src=0"

selectQLR <- "SELECT 
src as node, prr
FROM prr_clean a
WHERE dest=0"

x <- c()
direction <- 'rl'
selectQ <- selectQRL

for (i in seq(argStart, argc-1)){
  opt <- commandArgs()[i]
  val <- commandArgs()[i+1]
  if (opt == '--dir'){
    direction <- val
    if (direction == 'lr'){
      selectQ <- selectQLR
    }
    if (direction == 'rl'){
      selectQ <- selectQRL
    }
  }
  if ( opt == '--db'){
    fn <- val
    lbl <- commandArgs()[i+2]
    con <- dbConnect(dbDriver("SQLite"), dbname=fn)
    tmp <- dbGetQuery(con, selectQ, lbl)
    tmp$label <- lbl
    x <- rbind(x, tmp)
  }

  if ( opt == '--pdf' ){
    plotFile=T
    pdf(val, width=9, height=6, title="PRR Comparison CDF")
  }
  if ( opt == '--png' ){
    plotFile=T
    png(val, width=9, height=6, units="in", res=200)
  }
  if (opt == '--xmin'){
    xmin <- as.numeric(val)
  }
  if (opt == '--xmax'){
    xmax <- as.numeric(val)
  }
}

aggByNode <- ddply(x, .(label, node), summarise,
  prr=median(prr),
  prrSD=sd(prr)
)

#What this next thing means:
#  group by label
#  prr = list of unique PRRs for group
#  ecdf = ecdf of PRRs for group applied to list of unique PRRs
#         for group
#  (ecdf returns a function, applying it to a PRR gives you its
#    cumulative density)
aggCDF <- ddply(aggByNode, .(label), summarize, 
  prr=unique(prr),
  ecdf=ecdf(prr)(unique(prr)))

# #TODO add end points at (0,0): this makes the plot barf (I think
# # that it wants observations for each group to be contiguous?
# for (lbl in unique(aggCDF$label)){
#   aggCDF <- rbind(aggCDF, c(lbl, 0, 0))
# }
print(
  ggplot(aggCDF, aes(x=prr, y=ecdf, color=label))
  + geom_line()
  + scale_y_continuous(limits=c(0,1.0))
  + scale_x_continuous(limits=c(0,1.0))
  + theme_bw()
)
if ( plotFile){
  g<-dev.off()
}
