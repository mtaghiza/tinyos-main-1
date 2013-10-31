plotFile <- F
argc <- length(commandArgs())
argStart <- 1 + which (commandArgs() == '--args')
library(plyr)
library(ggplot2)
library(RSQLite)


# #it might be better to leave out the aggregation in sql, and just do
# #  it here in R
# selectQ <- "
# SELECT avgBS.*, agg_depth.avgDepth
# FROM (
#   SELECT src as node, avg(ipd) as avgIPD, avg(floodIpd) as floodIPD
#   FROM BURST_SPACING
#   GROUP BY src ) as avgBS
# JOIN agg_depth ON agg_depth.dest= avgBS.node and agg_depth.src=0
# ORDER BY agg_depth.avgDepth"

# selectQ <-"
#   SELECT dataCount.src as node, dataCount.burstNum,   
#     ipdSum/dataCount.cnt as ipd,
#     actualIpdSum/dataCount.cnt as actualIpd,
#     floodSpacing.floodIpd,
#     avgDepth
#   FROM (
#     SELECT src, burstNum, 1.0*count(*) as cnt
#     FROM BURST_SPACING
#     WHERE am != 0
#     GROUP BY src, burstNum
#   )  as dataCount
#   JOIN (
#     SELECT src, burstNum, 
#       sum(ipd) as ipdSum,
#       sum(actualIPD) as actualIpdSum
#     FROM BURST_SPACING
#     GROUP BY src, burstNum
#   ) as ipdSums
#   ON ipdSums.src=dataCount.src and ipdSums.burstNum=dataCount.burstNum
#   JOIN agg_depth on agg_depth.src=0 and agg_depth.dest=dataCount.src
#   JOIN (select max(depth) + 1 as floodIpd from RX_ALL) as floodSpacing
# " 

selectQ <- "SELECT src, tpi, avgDistance, fsTp, nofsTp FROM tpi_v_distance;"

x <- c()
nx <- c()
size <- 'small'
plotType <- 'scatterNorm'
slotLen <- (1024.0/32768)* 60
for (i in seq(argStart, argc-1)){
  opt <- commandArgs()[i]
  val <- commandArgs()[i+1]
  if ( opt == '--plotType'){
    plotType <- val
  }
  if ( opt == '--size'){
    size <- val
  }
  if ( opt == '--db'){
    fn <- val
    lbl <- commandArgs()[i+2]
    con <- dbConnect(dbDriver("SQLite"), dbname=fn)
    x <- rbind(x, dbGetQuery(con, selectQ))
  }
  if ( opt == '--pdf' ){
    plotFile=T
    if (size == 'small'){
      pdf(val, width=4, height=3, title="Throughput Improvement v. Distance")
    }else{
      pdf(val, width=8, height=4, title="Throughput Improvement v. Distance")
    }
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
print("raw loaded")

aggByNode <- ddply(x, .(src), summarize,
  tpi=mean(tpi),
  depth=mean(avgDistance),
  fsTp=mean(fsTp)/slotLen,
  nofsTp=mean(nofsTp)/slotLen)

print(
  ggplot(aggByNode, aes(x=depth, y=tpi))
  + geom_point()
  + xlab("Source Node Distance (hops)")
  + ylab("Throughput (relative to flood)")
  + theme_bw()
  + theme(legend.justification=c(1,1), legend.position=c(1,1))
  + theme(panel.grid.major=element_blank(),panel.grid.minor=element_blank())
)
print("Throughput improvement")
print(summary(aggByNode))
# aggByLabel <- ddply(x, .(label), summarize,
#   throughput=mean(floodIpd/ipd))
# print(aggByLabel)

if (plotFile){
  g <- dev.off()
}

