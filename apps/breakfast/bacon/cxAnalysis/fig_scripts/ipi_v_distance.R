plotFile <- F
argc <- length(commandArgs())
argStart <- 1 + which (commandArgs() == '--args')
library(plyr)
library(ggplot2)
library(RSQLite)

checkQ <- "SELECT count(*) from sqlite_master where type='table' and name like 'BURST_SPACING'"

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

selectQ <-"
  SELECT dataCount.src as node, dataCount.burstNum,   
    ipdSum/dataCount.cnt as ipd,
    actualIpdSum/dataCount.cnt as actualIpd,
    floodSpacing.floodIpd,
    avgDepth
  FROM (
    SELECT src, burstNum, 1.0*count(*) as cnt
    FROM BURST_SPACING
    WHERE am != 0
    GROUP BY src, burstNum
  )  as dataCount
  JOIN (
    SELECT src, burstNum, 
      sum(ipd) as ipdSum,
      sum(actualIPD) as actualIpdSum
    FROM BURST_SPACING
    GROUP BY src, burstNum
  ) as ipdSums
  ON ipdSums.src=dataCount.src and ipdSums.burstNum=dataCount.burstNum
  JOIN agg_depth on agg_depth.src=0 and agg_depth.dest=dataCount.src
  JOIN (select max(depth) + 1 as floodIpd from RX_ALL) as floodSpacing
" 

x <- c()
nx <- c()
plotType <- 'scatterNorm'
for (i in seq(argStart, argc-1)){
  opt <- commandArgs()[i]
  val <- commandArgs()[i+1]
  if ( opt == '--plotType'){
    plotType <- val
  }
  if ( opt == '--ndb'){
    fn <- val
    lbl <- commandArgs()[i+2]
    con <- dbConnect(dbDriver("SQLite"), dbname=fn)
    cTmp <- dbGetQuery(con, checkQ)
    if (cTmp[1] == 1){
      tmp <- dbGetQuery(con, selectQ)
      print(paste("Loaded", length(tmp$node), "from", fn))
      if (length(tmp$node) > 0 ){
        tmp$label <- lbl
        tmp$fn <- fn
        nx <- rbind(nx, tmp)
      }
    }else{
      print(paste("Skip", fn, "(no throughput data)"))
    }
  }
  if ( opt == '--db'){
    fn <- val
    lbl <- commandArgs()[i+2]
    con <- dbConnect(dbDriver("SQLite"), dbname=fn)
    cTmp <- dbGetQuery(con, checkQ)
    if (cTmp[1] == 1){
      tmp <- dbGetQuery(con, selectQ)
      print(paste("Loaded", length(tmp$node), "from", fn))
      if (length(tmp$node) > 0 ){
        tmp$label <- lbl
        tmp$fn <- fn
        x <- rbind(x, tmp)
      }
    }else{
      print(paste("Skip", fn, "(no slot data)"))
    }
  }

  if ( opt == '--pdf' ){
    plotFile=T
    pdf(val, width=4, height=3, title="RR Throughput v. Distance")
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

aggByNode <- ddply(x, .(label, node), summarize,
  ipd=mean(ipd),
  actualIpd=mean(actualIpd),
  floodIpd=mean(floodIpd),
  depth=mean(avgDepth))

print(
  ggplot(aggByNode, aes(x=depth, y=floodIpd/ipd, shape=label))
  + geom_hline(yintercept=c(1.0), col='gray')
  + geom_point()
  + scale_shape_manual(name="TX Power (dBm)",
    breaks=c('0x8D', '0x2D', '0x25'),
    labels=c(0, -6, -12),
    values=c(3, 2, 0))
  + xlab("Source Node Distance")
  + ylab("Normalized RR Burst throughput")
  + theme_bw()
  + theme(legend.justification=c(1,1), legend.position=c(1,1))
  + theme(panel.grid.major=element_blank(),panel.grid.minor=element_blank())
)

aggByLabel <- ddply(x, .(label), summarize,
  throughput=mean(floodIpd/ipd))
print(aggByLabel)

if (plotFile){
  g <- dev.off()
}
