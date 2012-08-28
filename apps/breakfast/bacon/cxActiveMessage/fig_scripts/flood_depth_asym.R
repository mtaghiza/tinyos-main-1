x<-read.csv('expansion/flood_depth_asym.csv')
o <- order(x$depth_rl)

plotFile=F
for (e in commandArgs()){
  if ( e == '--pdf' ){
    plotFile=T
    pdf('fig/flood_depth_asym.pdf', width=6, height=6, title="Average depth asymmetry")
  }
  if ( e == '--png' ){
    plotFile=T
    png('fig/flood_depth_asym.png', width=6, height=6, units="in", res=200)
  }
}

xl <- c(1, 5)
yl <- c(1, 5)
farther_rl <- x[x$depth_rl > x$depth_lr, ]
farther_lr <- x[x$depth_rl < x$depth_lr, ]
equal_lr <- x[x$depth_rl == x$depth_lr, ]
plot(farther_lr$depth_rl, farther_lr$depth_lr, col='red', 
  ylim=yl, xlim=xl, 
  xlab='Leaf->Root Distance', 
  ylab='Root->Leaf Distance')
par(new=T)
plot(farther_rl$depth_rl, farther_rl$depth_lr, col='blue',
  ylim=yl, xlim=xl, xlab='', ylab='', xaxt='n', yaxt='n')
par(new=T)
plot(equal_lr$depth_rl, equal_lr$depth_lr, col='black',
  ylim=yl, xlim=xl, xlab='', ylab='', xaxt='n', yaxt='n')
par(new=T)
plot(x=c(0,10), y=c(0,10), type='l', lty=2,
  ylim=yl, xlim=xl, xlab='', ylab='', xaxt='n', yaxt='n')

counts <- c( dim(farther_rl)[1], dim(farther_lr)[1], dim(equal_lr)[1])
means <- round(c(mean(farther_rl$depth_rl - farther_rl$depth_lr),
  mean(farther_lr$depth_lr - farther_lr$depth_rl),
  0), digits=2)
legend('topleft', 
  paste(c('R->L Longer:', 'L->R Longer:', 'Equal Length:'), counts,
  c('Avg diff:'), means),
  text.col=c('red', 'blue', 'black'))
title("Average Depth Asymmetries: Flood, no retx")

if ( plotFile){
  g<-dev.off()
}
