DROP TABLE IF EXISTS rx_tx_delta;

CREATE TABLE rx_tx_delta as
SELECT * 
--tCount.src, tCount.cnt - rCount.cnt
FROM 
  (
   SELECT 
   dest, 
   count(*) as rCount
   FROM RX
   WHERE src == 0
   GROUP BY dest
  ) rCount
  JOIN 
  (
   SELECT src, count(*) as tCount
   FROM TX 
   GROUP BY src
  ) tCount 
  on tCount.src == rCount.dest
;

DROP TABLE IF EXISTS rx_ordered;
CREATE TABLE rx_ordered as 
SELECT * from rx
WHERE src == 0
ORDER by dest, ts;

-- looking at this, we can see that basically all of the one-hop nodes
-- see a gap right at the start that corresponds to the synch timeout
-- period
DROP TABLE IF EXISTS rx_adj;
CREATE TABLE rx_adj as
SELECT l.dest as node, 
  l.ts as startGap,
  r.ts - l.ts as gapLen
FROM rx_ordered l
JOIN rx_ordered r
ON l.dest == r.dest AND l.rowid+1 == r.rowid
ORDER BY l.dest, l.ts;
