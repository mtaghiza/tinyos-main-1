x <- read.csv('expansion/depth_v_time_35.csv')

plotFile=F
for (e in commandArgs()){
  if ( e == '--pdf' ){
    plotFile=T
    pdf('fig/depth_v_time_35.pdf', width=9, height=6, title="Depth v.  Time (single node)")
  }
  if ( e == '--png' ){
    plotFile=T
    png('fig/depth_v_time_35.png', width=9, height=6, units="in", res=200)
  }
}

plot(x=x$ts-min(x$ts), y=x$depth, type='o', ylab='Depth',
  xlab='Time(s)')
title('Trace of 35->Root Distance')

if ( plotFile){
  g<-dev.off()
}
