plotRssi <- function(){
  x <- read.csv('rssi.csv')
  
  pde <- x[x$manufacturer=="pde",]
  plot(pde$dest, pde$rssi, type='p', col='black', 
    xlim=c( min(x$dest), max(x$dest)),
    ylim=c( min(x$rssi), max(x$rssi)))
  
  pcbfe <- x[x$manufacturer=="pcbfe",]
  points(pcbfe$dest, pcbfe$rssi, col='red')
  
  em <- x[x$manufacturer=="em",]
  points(em$dest, em$rssi, col='blue')
}

links <- read.csv('links.csv')

#roughly order by distance
aggRssi <- aggregate(data=links, avgRssi~(dest), FUN=mean)
#aggRssi[order(aggRssi$avgRssi),]

qs <- floor(quantile(1:length(aggRssi$avgRssi), c(0, 0.1, 0.25, 0.5, 0.75, 0.9, 1.0)))
#destinations <- aggRssi[qs,]$dest
destinations <- c(0, 6, 10)

aggPrr <- aggregate(data=links, prr~(manufacturer*dest), FUN=mean)

rx <- read.csv('rx.csv')
rssiFiltered <- c()
prrFiltered <- c()
#par(ask=TRUE)
for (d in destinations){
#  rssiFiltered <- rbind(rx[rx$dest==d,], rssiFiltered)
  rssiFiltered <- rx[rx$dest==d,]
  droplevels(rssiFiltered)
  prrFiltered <- rbind(aggPrr[aggPrr$dest==d,], prrFiltered)
  png(paste('fig/rssi_',d, '.png', sep=''))
  boxplot(rssi~(src*dest), data=rssiFiltered, las=2, ylim=c(-80, -20))
  title('Testbed RSSI (30x: PDE, 40x: PCBFE, 50x: EM)')
  g <- dev.off()
}

for (d in destinations){
  x <- links[links$dest == d,]
  png(paste('fig/prr_',d,'.png', sep=''))
  boxplot(prr~(src*dest), data=x, las=2, ylim=c(0,1.0))
  title('Testbed PRR (30x: PDE, 40x: PCBFE, 50x: EM)')
  g <-dev.off()
}
#boxplot(prr~(manufacturer*dest), data=prrFiltered)
