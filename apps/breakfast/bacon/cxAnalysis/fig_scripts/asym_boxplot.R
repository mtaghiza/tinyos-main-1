
selectQ <- "SELECT * FROM depth_asymmetry"
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
    pdf(val, width=9, height=6, title="Depth Asymmetry Boxplots")
  }
  if ( opt == '--png' ){
    plotFile=T
    png(val, width=9, height=6, units="in", res=200)
  }
}

library(RSQLite)
con <- dbConnect(dbDriver("SQLite"), dbname=fn)
x <- dbGetQuery(con, selectQ);

#x<- fetch(rs, n=-1)

yl <- c(1,9)
boxplot(depth~root*leaf, data=x[x$lr==0,], border='red', ylim=yl,
 ylab='Distance', xlab='', yaxt='n', pars=list(staplewex=1)
# ,xaxt='n'
 )
axis(side=2, at=1:9)
#par(new=T)
boxplot(depth~root*leaf, data=x[x$lr==1,], border='blue', col='blue',
  pars=list(boxwex=0.1, staplewex=5, cex=0.5), ylim=yl, add=T, yaxt='n'
#  ,xaxt='n'
  )

legend('topleft', c('Root->Leaf', 'Leaf->Root'), text.col=c('red', 'blue'))
title(main="Flood Depth Asymmetry")

if ( plotFile){
  g<-dev.off()
}
