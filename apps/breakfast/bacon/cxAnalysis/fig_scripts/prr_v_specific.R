library(RSQLite)

q0 <- "
SELECT '"
#label
q1 <- "' as label, n.* 
FROM prr_v_node n
  WHERE hopCount = "
# desired hop count
q2 <- " and sendCount = "
#num senders
q3 <- " and cnt > "
# threshold for number of occurrences

hc <- 2
ns <- 0
countThresh <- 200

fn <- ''
plotFile <- F
argc <- length(commandArgs())
argStart <- 1 + which (commandArgs() == '--args')
x <- c()
hc <- 2
for (i in seq(argStart, argc-1)){
  opt <- commandArgs()[i]
  val <- commandArgs()[i+1]
  if ( opt == '-c'){
    hc <- as.numeric(val)
  }
  if (opt == '-n'){
    ns <- as.numeric(val)
  }
  if (opt == '-t'){
    countThresh <- as.numeric(val)
  }
  if ( opt == '-f'){
    fn <- val
    lbl <- commandArgs()[i+2]
    con <- dbConnect(dbDriver("SQLite"), dbname=fn)
    selectQ <- paste(q0, lbl, q1, hc, q2, ns, q3, countThresh)
    x <- rbind(x, dbGetQuery(con, selectQ ))
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
