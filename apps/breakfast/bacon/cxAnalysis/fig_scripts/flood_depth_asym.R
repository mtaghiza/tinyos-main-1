selectQ <- "SELECT
  rl.src as root,
  rl.dest as leaf,
  rl.avgDepth as depth_rl,
  lr.avgDepth as depth_lr
FROM agg_depth rl
JOIN agg_depth lr 
ON lr.src = rl.dest and lr.dest = rl.src
WHERE rl.src = 0";

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
    pdf(val, width=9, height=9, title="Depth Asymmetry Scatterplot")
  }
  if ( opt == '--png' ){
    plotFile=T
    png(val, width=9, height=9, units="in", res=200)
  }
}

library(RSQLite)
con <- dbConnect(dbDriver("SQLite"), dbname=fn)


x<- dbGetQuery(con, selectQ)



o <- order(x$depth_rl)
xl <- c(1, 5)
yl <- c(1, 5)
margin <- 0.5
farther_rl <- x[x$depth_rl > x$depth_lr + margin, ]
farther_lr <- x[x$depth_rl < x$depth_lr - margin, ]
equal_lr <- x[x$depth_rl >= x$depth_lr - margin 
  & x$depth_rl <= x$depth_lr+margin, ]
plot(farther_lr$depth_rl, farther_lr$depth_lr, col='red', 
  ylim=yl, xlim=xl, 
  xlab='Leaf->Root Distance', 
  ylab='Root->Leaf Distance')
points(farther_rl$depth_rl, farther_rl$depth_lr, col='blue')
points(equal_lr$depth_rl, equal_lr$depth_lr, col='black')
lines(c(-10,10), y=c(-10,10) + margin, col='gray')
lines(c(-10,10), y=c(-10,10) - margin, col='gray')

counts <- c( dim(farther_rl)[1], dim(farther_lr)[1], dim(equal_lr)[1])
means <- round(c(mean(farther_rl$depth_rl - farther_rl$depth_lr),
  mean(farther_lr$depth_lr - farther_lr$depth_rl),
  mean(equal_lr$depth_lr - equal_lr$depth_rl)), digits=2)
legend('topleft', 
  paste(c('R->L Longer:', 'L->R Longer:', paste('Within', margin, ':')), counts,
  c('Avg diff:'), means, c('', '', '(- indicates rl > lr)')),
  text.col=c('blue', 'red', 'black'))
title("Average Depth Asymmetries: Flood, no retx")

if ( plotFile){
  g<-dev.off()
}
