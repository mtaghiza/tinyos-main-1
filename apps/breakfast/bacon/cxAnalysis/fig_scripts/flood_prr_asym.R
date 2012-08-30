selectQ <- "SELECT 
  a.src,
  a.dest,
  a.prr as prr_rl,
  b.prr as prr_lr
FROM prr_clean a
JOIN prr_clean b
  ON a.src=b.dest AND b.src=a.dest
  AND a.tp=b.tp
  AND a.np=b.np
  AND a.pr=b.pr
WHERE a.src=0"

fn <- ''
plotFile <- F
argc <- length(commandArgs())
argStart <- 1 + which (commandArgs() == '--args')

for (i in seq(argStart, argc-1)){
  opt <- commandArgs()[i]
  val <- commandArgs()[i+1]
  if ( opt == '-f'){
    fn <- val
  }
  if ( opt == '--pdf' ){
    plotFile=T
    pdf(val, width=9, height=6, title="Flood PRR Asymmetry Series")
  }
  if ( opt == '--png' ){
    plotFile=T
    png(val, width=9, height=6, units="in", res=200)
  }
}

library(RSQLite)
con <- dbConnect(dbDriver("SQLite"), dbname=fn)
rs <- dbSendQuery(con, selectQ);

x<- fetch(rs, n=-1)

o <- order(x$prr_lr)
n <- length(o)

#order+line by lr, points for rl
yl<- c(0.4, 1.0)
plot(x$prr_rl[o], ylim=yl, type='p', col='red', cex=0.5, ylab='PRR', 
  xlab='Node ID (re-ordered for clarity)')
par(new=T)
plot(x$prr_lr[o], ylim=yl, type='l', col='blue', ylab='', yaxt='n',
  xaxt='n', xlab='')
title('Flood PRR Asymmetry (no retx)')
legend('bottomright', c('Root->Leaf', 'Leaf->Root'), text.col=c('red',
'blue'))

## lr v. rl
#plot(x=x$prr_lr[o], y=x$prr_rl[o], xlim=c(0,1.0), ylim=c(0,1.0))

if ( plotFile){
  g<-dev.off()
}
