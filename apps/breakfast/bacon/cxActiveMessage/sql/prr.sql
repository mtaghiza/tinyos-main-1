SELECT 
  a.src,
  a.dest,
  a.prr as rl,
  b.prr as lr
FROM prr a
JOIN prr b
  ON a.src=b.dest AND a.dest=b.src
WHERE a.dest=0 AND a.pr=0 AND b.pr = 0;
