DROP TABLE IF EXISTS comparison;

CREATE TEMPORARY TABLE comparison AS 
SELECT 
  agg_depth.src as src, 
  agg_depth.dest as dest, 
  agg_depth.avgDepth as cxDepth, 
  depth.depth as depth,
  depth.depth - agg_depth.avgDepth as cxImprovement,
  agg_depth.sdDepth as cxSdev
FROM agg_depth 
JOIN depth 
  ON agg_depth.src = depth.src 
  AND agg_depth.dest = depth.dest;
