
#boxplots:
# capture node alone
# rssi distribution for each num senders


library(RSQLite)
q0 <- "SELECT '"
q1 <- "' as label,
  sendCount,
  rssi
FROM group_results
WHERE hopCount= "
q2<-" AND sendCount= "

fn <- ''
plotFile <- F
argc <- length(commandArgs())
argStart <- 1 + which (commandArgs() == '--args')
raw <- c()
hc <- 2
cap <- 6
for (i in seq(argStart, argc-1)){
  opt <- commandArgs()[i]
  val <- commandArgs()[i+1]
  if ( opt == '-f'){
    fn <- val
    sc <- commandArgs()[i+2]
    lbl <- commandArgs()[i+3]
    con <- dbConnect(dbDriver("SQLite"), dbname=fn)
    selectQ <- paste(q0, lbl, q1, hc, q2, sc, sep='')
#    print(selectQ)
    raw <- rbind(raw, dbGetQuery(con, selectQ ))
  }
  if (opt == '--cap'){
    cap <- as.numeric(val)
  }
  if ( opt == '--pdf' ){
    plotFile=T
    pdf(val, width=9, height=9, title="PRR v. Senders")
  }
  if ( opt == '--png' ){
    plotFile=T
    png(val, width=9, height=9, units="in", res=200)
  }
}
raw$label[raw$label == 'nocap'] = 0

raw$supp <- paste(raw$sendCount, 'TX +', raw$label)
boxplot(rssi~supp, 
  data=raw, 
  subset=(label =='0' | supp==paste('1 TX +', cap)),
  las=1,
  xlab='#Senders + separation (dBm) of strongest')
title("Reported RSSI with Multiple Senders and Capture Effect")

if (plotFile){
  g <- dev.off()
}
