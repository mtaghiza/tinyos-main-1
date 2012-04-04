.mode csv
SELECT rx_adj.node as node, 
  round(avgDepth) as depth, 
  startGap - testStart.ts as ts, 
  round(gapLen/20.8) as mc
FROM rx_adj 
JOIN
  (select min(startGap) as ts from rx_adj) testStart
JOIN agg_depth ON agg_depth.node == rx_adj.node
order by startGap;

