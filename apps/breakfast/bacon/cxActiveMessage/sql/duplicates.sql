DROP TABLE IF EXISTS dup_rx;
CREATE TEMPORARY TABLE dup_rx AS 
  SELECT * FROM (
    SELECT src, dest, sn, count(*) AS cnt 
    FROM rx_all GROUP BY src, dest, sn
  ) where cnt > 1;


DROP TABLE IF EXISTS dup_tx;
CREATE TEMPORARY TABLE dup_tx AS
  SELECT tx_all.*
  FROM tx_all 
  JOIN (
    SELECT DISTINCT src, sn 
    FROM dup_rx) d
  ON tx_all.src=d.src AND tx_all.sn = d.sn 
  ORDER BY ts;

SELECT r.*, r.ts-l.ts
FROM dup_tx l
JOIN dup_tx r
ON l.rowid+1 = r.rowid;
  
