--this is what we would see if we probed the network in both
--directions: between s and d in s->d direction, between d and s in
--d->s direction.

SELECT 
  sd.dest, sd.sdd,
  ds.dsd, sd.sdd+ds.dsd
FROM ( 
  SELECT dest, agg_depth.avgDepth as sdd
  FROM agg_depth 
  JOIN (
    SELECT avgDepth FROM agg_depth where src=0 and dest = 40) sd_depth 
  WHERE src = 0 and agg_depth.avgDepth < sd_depth.avgDepth ) sd
JOIN ( 
  SELECT dest, agg_depth.avgDepth as dsd
  FROM agg_depth 
  JOIN (
    SELECT avgDepth FROM agg_depth where dest=0 and src = 40) ds_depth 
  WHERE src = 40 and agg_depth.avgDepth < ds_depth.avgDepth ) ds 
ON ds.dest = sd.dest 
ORDER BY sd.sdd;
--ORDER BY ds.dsd;
