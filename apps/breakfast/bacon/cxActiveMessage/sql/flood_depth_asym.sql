.mode csv
SELECT
  rl.src as root,
  rl.dest as leaf,
  rl.avgDepth as depth_rl,
  lr.avgDepth as depth_lr
FROM agg_depth rl
JOIN agg_depth lr 
ON lr.src = rl.dest and lr.dest = rl.src
WHERE rl.src = 0;
