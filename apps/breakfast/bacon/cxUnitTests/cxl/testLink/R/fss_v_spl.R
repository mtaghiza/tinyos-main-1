plotFile <- F
argc <- length(commandArgs())
argStart <- 1 + which (commandArgs() == '--args')
library(plyr)
library(ggplot2)
library(RSQLite)

spc_v_cxcQ <- "SELECT cx.src as src, 
  cx.dest as dest, 
  cx_cnt,
  sp_cnt
FROM (
  SELECT src, dest, 
    count(*) as cx_cnt
  FROM cxfs 
  WHERE bw=2
  GROUP BY src, dest ) as cx
JOIN (
  SELECT src, dest,
    count(*) as sp_cnt
  FROM sp_thresh_entry
  WHERE prr=0.99
  GROUP BY src, dest ) as sp
ON sp.src=cx.src and sp.dest=cx.dest
";

spl_v_cxlQ <- "SELECT cx.src as src, 
  cx.dest as dest, 
  cx_len,
  sp_len,
  cx_len < sp_len as cx_shorter
FROM (
  SELECT src, dest, hc as cx_len
  FROM mtl
  ) as cx
JOIN (
  SELECT src, dest,
    count(*)-1 as sp_len
  FROM sp_thresh_entry
  WHERE prr=0.99
  GROUP BY src, dest ) as sp
ON sp.src=cx.src and sp.dest=cx.dest";

xmin <- 0
xmax <- 60
ymin <- 0
ymax <- 10
plotType <- 'size'
size <- 'big'
spc_v_cxc <- c()
spl_v_cxl <- c()
pdfFile <- ''
lpos <- c(1,0)

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
    spc_v_cxc <- rbind(spc_v_cxc, 
      dbGetQuery(con, spc_v_cxcQ))
    spl_v_cxl <- rbind(spl_v_cxl, 
      dbGetQuery(con, spl_v_cxlQ))
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
}

if (plotType == 'size'){
  t <- "CX size v. SP size"
}else if (plotType == 'length'){
  t <- "CX len v. SP len"
}else if (plotType == 'sizeHist'){
  t <- "CX size v. SP size histogram"
}

if (pdfFile != ''){
  if (size == 'small'){
    pdf(val, width=4, height=3, title=t)
  }else{
    pdf(val, width=8, height=4, title=t)
  }
}

##sp count vs. cx count
if (plotType == 'size'){
  print(
    ggplot(spc_v_cxc, aes(x=cx_cnt, y=sp_cnt))
    + geom_point(alpha=0.25)
    + theme_bw()
    + xlab("Nodes in Forwarder Set")
    + ylab("Nodes in Shortest Path (>0.99 PRR links)")
  )
# plot(spc_v_cxc$cx_cnt, spc_v_cxc$sp_cnt)
}

if (plotType == 'sizeHist'){
  bw <- 1.0
  print(
    ggplot(spc_v_cxc, aes((cx_cnt/sp_cnt)-bw/2))
    + geom_histogram(aes(y=..count../sum(..count..)),
      fill='white',
      color='black',
      binwidth=bw)
    + ylab("Fraction of node pairs")
    + xlab("|Frr| / |Fmin|")
    + theme_bw()
  )
  print(mean(spc_v_cxc$cx_cnt/spc_v_cxc$sp_cnt))
}

#sp len vs. avg cx len
if (plotType == 'length'){
  spl_v_cxl$cx_shorter_fac <- as.factor(spl_v_cxl$cx_shorter)
  print (
    ggplot(spl_v_cxl, aes(x=cx_len, y=sp_len, col=cx_shorter_fac))
    + geom_point()
    + scale_color_manual(name='',
      breaks=c(0,1),
      labels=c('CX Longer',
        'CX Shorter'),
      values=c('black','gray'))
    + xlab("Avg. CX Distance")
    + ylab("Single-TX Path Length (>0.99 PRR links)")
    + theme_bw()
    + theme(legend.position=lpos, legend.justification=lpos)
  )

#  plot(spl_v_cxl$cx_len, spl_v_cxl$sp_len, col=1+spl_v_cxl$cx_shorter)
#  lines(x=c(0,10), y=c(0,10))
}

if (plotType == 'lengthHist'){
  bw <- 0.05
  print(
    ggplot(spl_v_cxl, aes((cx_len/sp_len)))
    + geom_histogram(aes(y=..count../sum(..count..)),
      fill='white',
      color='black',
      binwidth=bw)
    + ylab("Fraction of node pairs")
    + xlab("Average Multi-TX Distance / Shortest Path Length")
    + theme_bw()
  )
  print(mean(spl_v_cxl$cx_len/spl_v_cxl$sp_len))
}

if (plotFile){
  g <-dev.off()
}
