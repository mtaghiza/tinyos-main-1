plotFile <- F
argc <- length(commandArgs())
argStart <- 1 + which (commandArgs() == '--args')
library(plyr)
library(ggplot2)
library(RSQLite)

selectQ1 <- "SELECT 
  rf.type as type, rf.src as src, rf.dest as dest,
  orig.testPrr as prrBase,
  orig.testHC as hcBase,
  rf.floodHC as floodHC,
  rf.f as f,
  rf.testPrr as prr,
  rf.testHC as hc,
  CASE 
    WHEN floodHC between 2.0 and 2.5 THEN '2 - 2.5'
    WHEN floodHC between 2.5 and 3.5 THEN '2.5 - 3.5'
    WHEN floodHC between 3.5 and 4.5 THEN '3.5 - 4.5'
    WHEN floodHC > 4.5 THEN '> 4.5'
    ELSE 'other' END as bin
FROM 
( 
  SELECT  type, src, dest, testPrr, testHC
  FROM reliability_final
  WHERE f=0.0) as orig
JOIN reliability_final as rf
ON rf.type=orig.type
  AND rf.src=orig.src
  AND rf.dest=orig.dest
ORDER by hcBase, rf.type, rf.f
";

selectQ2 <-" SELECT 
  orig.src as src, orig.dest as dest,
  orig.testPrr as prrBase,
  orig.testHC as hcBase,
  orig.floodHC as floodHC,
  rfc.f as f,
  rfc.testPrr as prrCX,
  rfc.testHC as hcCX,
  rfs.testPrr as prrSP,
  rfs.testHC as hcSP,
  CASE 
    WHEN orig.floodHC between 2.0 and 2.5 THEN '2 - 2.5'
    WHEN orig.floodHC between 2.5 and 3.5 THEN '2.5 - 3.5'
    WHEN orig.floodHC between 3.5 and 4.5 THEN '3.5 - 4.5'
    WHEN orig.floodHC > 4.5 THEN '> 4.5'
    ELSE 'other' END as bin
FROM 
( 
  SELECT  type, src, dest, testPrr, testHC, floodHC
  FROM reliability_final
  WHERE f=0.0) as orig
JOIN reliability_final as rfc
ON 
  rfc.src=orig.src
  AND rfc.dest=orig.dest
  AND rfc.type='cx'
JOIN reliability_final as rfs
ON 
  rfs.src=orig.src
  AND rfs.dest=orig.dest
  AND rfs.type='sp'
ORDER by floodHC, f"

selectQ3 <- "SELECT 
  orig_cx.src as src, orig_cx.dest as dest,
  orig_cx.floodHC as floodHC,
  orig_cx.testPrr as prrBaseCX,
  orig_cx.testHC as hcBaseCX,
  orig_sp.testPrr as prrBaseSP,
  orig_sp.testHC as hcBaseSP,
  rfc.f as f,
  rfc.testPrr as prrCX,
  rfc.testHC as hcCX,
  rfs.testPrr as prrSP,
  rfs.testHC as hcSP,
  CASE 
    WHEN orig_cx.floodHC between 2.0 and 2.5 THEN '2 - 2.5'
    WHEN orig_cx.floodHC between 2.5 and 3.5 THEN '2.5 - 3.5'
    WHEN orig_cx.floodHC between 3.5 and 4.5 THEN '3.5 - 4.5'
    WHEN orig_cx.floodHC > 4.5 THEN '> 4.5'
    ELSE 'other' END as bin
FROM 
( 
  SELECT  type, src, dest, testPrr, testHC, floodHC
  FROM reliability_final
  WHERE f=0.0 and type='cx') as orig_cx
JOIN 
( 
  SELECT  type, src, dest, testPrr, testHC, floodHC
  FROM reliability_final
  WHERE f=0.0 and type='sp') as orig_sp
ON orig_cx.src= orig_sp.src
  AND orig_cx.dest=orig_sp.dest
JOIN reliability_final as rfc
ON 
  rfc.src=orig_cx.src
  AND rfc.dest=orig_cx.dest
  AND rfc.type='cx'
JOIN reliability_final as rfs
ON 
  rfs.src=orig_cx.src
  AND rfs.dest=orig_cx.dest
  AND rfs.type='sp'
  AND rfs.f=rfc.f
ORDER by floodHC, f" 


xmin <- 0
xmax <- 60
ymin <- 0
ymax <- 10
plotType <- 'normalized'
size <- 'big'
x <- c()
pdfFile <- ''
lpos <- c(0,0)
plotBW <- 1

filterVal <- ''

for (i in seq(argStart, argc-1)){
  opt <- commandArgs()[i]
  val <- commandArgs()[i+1]
  if (opt =='--size'){
    size <- val
  }
  if ( opt == '--plotType'){
    plotType <- val
  }
  if ( opt == '--db'){
    fn <- val
    con <- dbConnect(dbDriver("SQLite"), dbname=fn) 
    x <- rbind(x, dbGetQuery(con, selectQ1))
  }

  if ( opt == '--pdf' ){
    plotFile=T
    pdfFile <- val
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
  if (opt == '--ymin'){
    ymin <- as.numeric(val)
  }
  if (opt == '--ymax'){
    ymax <- as.numeric(val)
  }
  if (opt=='--lpos'){
    if (val == 'ur'){
      lpos <- c(1,1)
    }else if (val == 'ul'){
      lpos <- c(0,1)
    }else if (val == 'br'){
      lpos <- c(1,0)
    }else if (val == 'bl'){
      lpos <- c(0,0)
    }
  }
  if (opt == '--plotBW'){
    plotBW <- as.numeric(val)
  }
  if (opt == '--filter'){
    filterVal <- val
  }
}

t <- "PRR v. failure rate"
if (pdfFile != ''){
  if (size == 'small'){
    pdf(val, width=4, height=3, title=t)
  }else{
    pdf(val, width=8, height=5, title=t)
  }
}

if (filterVal != ''){
  x <- x[x$type == filterVal,]
}

if (plotType == 'normalized'){
  agg <- ddply(x, .(type, bin, f), summarize,
    fracPRR = mean(prr/prrBase),
    fracHC = mean(hc/hcBase))
  print (
    ggplot(agg, aes(x=f,y=fracPRR, linetype=bin, shape=type, group=interaction(type, bin)))
    + geom_line()
    + geom_point(size=3)
    + xlab('Node Failure Rate')
    + ylab('Normalized PRR')
    + scale_shape_discrete(name='Nodes Used',
      breaks=c('cx', 'sp'),
      labels=c('CXFS', 'Shortest Path'))
    + scale_linetype_discrete(name='Average Flood Distance (Hops)')
    + theme_bw()
    + theme(legend.justification=lpos, legend.position=lpos)
  )
}

if(plotType == 'absolute'){
  agg <- ddply(x, .(type, bin, f), summarize,
    prr = mean(prr),
    hc = mean(hc))
  if (plotBW){
    print (
      ggplot(agg, aes(x=f,y=prr, linetype=bin, shape=type, group=interaction(type, bin)))
      + geom_line()
      + geom_point(size=3)
      + xlab('Node Failure Rate')
      + ylab('PRR')
      + scale_shape_discrete(name='Nodes Used',
        breaks=c('cx', 'sp'),
        labels=c('CXFS', 'Shortest Path'))
      + scale_linetype_discrete(name='Average Flood Distance (Hops)')
      + theme_bw()
      + theme(legend.justification=lpos, legend.position=lpos)
    )
  }else{
    print (
      ggplot(agg, aes(x=f,y=prr, linetype=bin, color=type, group=interaction(type, bin)))
      + geom_line()
      + geom_point(size=3)
      + xlab('Node Failure Rate')
      + ylab('PRR')
      + scale_y_continuous(limits=c(0,1))
      + scale_color_manual(name='Nodes Used',
        values=c('sp'='red', 'cx'='blue'),
        labels=c('sp'='Shortest Path', 'cx'='CXFS'))
      + scale_linetype_discrete(name='Average Flood Distance (Hops)')
      + theme_bw()
      + theme(legend.justification=lpos, legend.position=lpos)
    )

  }

}

if (plotFile){
  g <-dev.off()
}

