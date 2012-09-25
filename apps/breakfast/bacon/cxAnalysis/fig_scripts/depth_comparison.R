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
    lbl <- commandArgs()[i+2]
    y <- read.csv(fn)
    y$lbl <- lbl
    if (is.null(dim(x))){
      x <- y
    }else{
      x <- merge(x, y, by=c('node'))
    }
  }
  if ( opt == '--pdf' ){
    plotFile=T
    pdf(val, width=9, height=9, title="Sim v. CX depth")
  }
  if ( opt == '--png' ){
    plotFile=T
    png(val, width=9, height=9, units="in", res=200)
  }
}
x <- x[x$distance.x !=0 & x$distance.y!= 0,]
margin <- 0.5
closerY <- x[x$distance.x > x$distance.y + margin,]
fartherY <- x[x$distance.x < x$distance.y - margin,]
equalY <- x[x$distance.x >= x$distance.y - margin 
  & x$distance.x <= x$distance.y + margin ,]

plot(fartherY$distance.x, fartherY$distance.y, col='red', 
    xlim=c(0,5), ylim=c(0,5),
    xlab=paste(x$lbl.x[1], 'Distance'),
    ylab=paste(x$lbl.y[1], 'Distance'))
points(closerY$distance.x, closerY$distance.y, col='blue')
points(equalY$distance.x, equalY$distance.y, col='black')
lines(c(-10, 10), c(-10,10) - margin, col='gray')
lines(c(-10, 10), c(-10,10) + margin, col='gray')
depth1Both <- dim(x[x$distance.x==1 & x$distance.y==1,])[1]
text(1,1, paste(depth1Both," at depth=1"), adj=c(-0.1, 1.1))
legend('topleft', c(paste(x$lbl.y[1], 'Farther:', dim(fartherY)[1]), 
    paste(x$lbl.x[1], 'Farther:', dim(closerY)[1]),
    paste('Within', margin,':', dim(equalY)[1])),
    text.col=c('red', 'blue', 'black'))
title('Simulated (serial) flood depth and actual CX flood depth')

if (plotFile){
  g<-dev.off()
}
