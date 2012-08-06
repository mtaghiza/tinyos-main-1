SELECT
  sd.src as src,
  sd.dest as dest,
  sd.avgDepth as dist_sd,
  sd.sdDepth as sdev_sd,
  ds.avgDepth as dist_ds,
  ds.sdDepth as sdev_ds,
  abs(sd.avgDepth - ds.avgDepth) as absDiff,
  sd.avgDepth - ds.avgDepth as diff,
  sd.sdDepth - ds.sdDepth as sd_diff
FROM agg_depth sd
JOIN agg_depth ds 
ON sd.src = ds.dest and sd.dest = ds.src
WHERE sd.src < sd.dest
AND sd.src = 0
ORDER BY absDiff;
