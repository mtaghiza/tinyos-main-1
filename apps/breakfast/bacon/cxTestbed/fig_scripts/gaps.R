x <- read.csv('debug/gaps.csv')

#pdf('debug/gaps.pdf', title="schedule gaps")
png('debug/gaps.png')
#, title="schedule gaps")
plot(-10,-10, 
  xlim=c(0, max(x$ts)), 
  ylim=c(0, max(x$mc)),
  xlab="Time (s)",
  ylab="Schedules missed")
depths <- unique(x$depth)
plotCols <- rainbow(length(depths))
for (i in seq_along(depths)){
  d <- depths[i]
  ad <- x[x$depth==d,]
  points(ad$ts, ad$mc+((i-1)/5), col=plotCols[i], pch=20)
}
legend("topright", pch=20, col=plotCols, legend=depths, title="depth")
title("Gaps in schedule receptions at 100k")

garbage <- dev.off()
