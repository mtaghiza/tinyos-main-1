x<-read.csv('data/flood_prr_asym.csv')
o <- order(x$prr_lr)
n <- length(o)

plotFile=F
for (e in commandArgs()){
  if ( e == '--pdf' ){
    plotFile=T
    pdf('fig/flood_prr_asym.pdf', width=9, height=6, title="Flood PRR Asymmetry")
  }
  if ( e == '--png' ){
    plotFile=T
    png('fig/flood_prr_asym.png', width=9, height=6, units="in", res=200)
  }
}

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
