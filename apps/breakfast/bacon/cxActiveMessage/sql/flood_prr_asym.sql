.mode csv
--flood PRR asym
SELECT 
  a.src,
  a.dest,
  a.prr as prr_rl,
  b.prr as prr_lr
FROM prr_clean a
JOIN prr_clean b
  ON a.src=b.dest AND b.src=a.dest
  AND a.tp=b.tp
  AND a.np=b.np
  AND a.pr=b.pr
WHERE a.src=0;
