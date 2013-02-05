plotFile <- F
argc <- length(commandArgs())
argStart <- 1 + which (commandArgs() == '--args')
library(plyr)
library(ggplot2)
library(RSQLite)

# this gives us the raw node, slot, dc, distance pairs for the test
checkQ <- "SELECT count(*) from sqlite_master where type='table' and name like 'SLOT_STATE_TOTALS'"

selectQ <- "
SELECT active_slot.node as node, 
  active_slot.slot - 1 as slot,
  coalesce(1.0*active_slot.total/total_slot.total, 0) as slotDC,
  avgDepth
FROM
(SELECT node, slot, sum(total) as total
FROM SLOT_STATE_TOTALS 
WHERE state in (select state from active_states) 
  and node not in (select node from error_events)
GROUP BY node, slot) as active_slot
JOIN 
(SELECT node, slot, sum(total) as total
FROM SLOT_STATE_TOTALS
GROUP BY node, slot) as total_slot
ON active_slot.node=total_slot.node 
   and active_slot.slot = total_slot.slot
JOIN agg_depth ON agg_depth.src=0 and agg_depth.dest=active_slot.slot
WHERE active_slot.slot not in (select node from error_events)"

x <- c()
nx <- c()
xmin <- 0
xmax <- 0
ymin <- 0
ymax <- 0
plotType <- 'ordered'
size <- 'small'
for (i in seq(argStart, argc-1)){
  opt <- commandArgs()[i]
  val <- commandArgs()[i+1]
  if (opt =='--size'){
    size <- val
  }
  if ( opt == '--plotType'){
    plotType <- val
  }
  if ( opt == '--ndb'){
    fn <- val
    bn <- strsplit(fn, '\\.')[[1]]
    bn <- bn[length(bn)-1]
    if (bn %in% nx$bn){
    #  print(paste("Duplicate", fn))
      next
    }    
    lbl <- commandArgs()[i+2]
    con <- dbConnect(dbDriver("SQLite"), dbname=fn)
    cTmp <- dbGetQuery(con, checkQ)
    if (cTmp[1] == 1){
      tmp <- dbGetQuery(con, selectQ)
      print(paste("Loaded", length(tmp$node), "from", fn))
      if (length(tmp$node) > 0 ){
        tmp$label <- lbl
        tmp$fn <- fn
        tmp$bn <- bn
        nx <- rbind(nx, tmp)
      }
    }else{
      print(paste("Skip", fn, "(no slot data)"))
    }
  }
  if ( opt == '--db'){
    fn <- val
    bn <- strsplit(fn, '\\.')[[1]]
    bn <- bn[length(bn)-1]
    if (bn %in% x$bn){
    #  print(paste("Duplicate", fn))
      next
    }    
    lbl <- commandArgs()[i+2]
    con <- dbConnect(dbDriver("SQLite"), dbname=fn)
    cTmp <- dbGetQuery(con, checkQ)
    if (cTmp[1] == 1){
      tmp <- dbGetQuery(con, selectQ)
      print(paste("Loaded", length(tmp$node), "from", fn))
      if (length(tmp$node) > 0 ){
        tmp$label <- lbl
        tmp$fn <- fn
        tmp$bn <- bn
        x <- rbind(x, tmp)
      }
    }else{
      print(paste("Skip", fn, "(no slot data)"))
    }
  }

  if ( opt == '--pdf' ){
    plotFile=T
    if (size == 'small'){
      pdf(val, width=4, height=3, title="Network DC v. Source Distance")
    }else{
      pdf(val, width=8, height=4, title="Network DC v. Source Distance")
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
  if (opt == '--ymin'){
    ymin <- as.numeric(val)
  }
  if (opt == '--ymax'){
    ymax <- as.numeric(val)
  }
}
print("raw loaded")
aggBySlot <- ddply(x, .(label, slot), summarise,
  dc=mean(slotDC),
  dcsd=sd(slotDC),
  depth=mean(avgDepth)
) 
if (ymax == 0){
  ymax=max(aggBySlot$dc)
}
if (xmax == 0){
  xmax=max(aggBySlot$depth)
}

if (plotType == 'scatter'){
  print(
    ggplot(aggBySlot, aes(x=depth, y=dc, shape=label)) 
    + geom_point(size=1.75)
    + geom_smooth(method=lm,se=FALSE, fullRange=T, aes(linetype=label))
    + theme_bw()
    + scale_y_continuous(limits=c(ymin, ymax))
    + scale_x_continuous(limits=c(xmin, xmax))
    + scale_linetype_manual(name="TX Power (dBm)",
      breaks=c('0x8D', '0x2D', '0x25'),
      labels=c(0, -6, -12),
      values=c(1,  2, 3))
    + scale_shape_manual(name="TX Power (dBm)",
      breaks=c('0x8D', '0x2D', '0x25'),
      labels=c(0, -6, -12),
      values=c(3, 2, 0))
    + xlab("Source Node Distance")
    + ylab("Avg. DC at Others [0, 1.0]")
    + theme(legend.justification=c(1,0), legend.position=c(1,0))
    + theme(panel.grid.major=element_blank(),panel.grid.minor=element_blank())
  )
}
if (plotType == 'ordered'){
  pd <- position_dodge(0.1)
  print(
    ggplot(aggBySlot, aes(x=reorder(slot, depth), y=dc, color=label))
    + geom_point(pos=pd)
    + geom_errorbar(aes(ymin=dc-dcsd, ymax=dc+dcsd), width=0.4, pos=pd)
    + theme_bw()
  )
}
if (plotType == 'matrix'){
  library(lattice)
  
  depths <- ddply(x, .(slot), summarize, depth=mean(avgDepth))
  depths <- depths[order(depths$depth),]
  depths$newId<- seq(length(depths$depth))
  
  #TODO re-order by distance
  agg <- ddply(x, .(node, slot), summarize,
    dc=mean(slotDC))
  
  hor <- unique(agg$slot)
  ver <- unique(agg$node)
  
  nrows <- length(ver)
  ncols <- length(hor)
  
  hm <- matrix(0, nrow=nrows, ncol=ncols, dimnames=list(hor, ver))
  for (i in seq(dim(agg)[1])){
    cur <- agg[i,]
    row <- cur$node
    col <- cur$slot
    dc <- cur$dc
    #column-major order, don't forget
    hm[as.character(col), as.character(row)] = dc
  }
  rgb.palette <- colorRampPalette(c("blue", "yellow"), space = "rgb")
  
  print(
  levelplot(hm, 
    main="", 
    xlab="Slot", ylab="Node",
    col.regions=rgb.palette(120), 
    at=seq(0, 0.05, 0.004))
  )
}
if (plotFile){
  g <-dev.off()
}
