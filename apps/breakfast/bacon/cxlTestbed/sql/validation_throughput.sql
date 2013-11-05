DROP TABLE IF EXISTS tests_vt;
CREATE TABLE tests_vt AS 
SELECT label.it as it
FROM label 
JOIN prr_summary
ON label.it=prr_summary.it
WHERE multitier=0 and ppd=50 and fps=60 and tpl=12
AND min(lr, rl) > 0.98
;

--the last slot for each of these nodes drags down its average (since
-- it doesn't use the full slot) 
DROP TABLE IF EXISTS slot_capacity;
CREATE TABLE slot_capacity
AS
SELECT label.it as it, efs, src, wn, slotNum, count(*) as cnt
FROM tests_vt
JOIN Label on Label.it=tests_vt.it
JOIN tx 
  ON tx.it= Label.it
WHERE tx.mt=0
GROUP BY label.it, efs, src, wn, slotNum
;

--this query only uses the first 120 slots (2 full cycles). Nodes
-- should still have data queued at this point.
DROP TABLE IF EXISTS slot_capacity_first;
CREATE TABLE slot_capacity_first
AS
SELECT it, efs, src, wn, slotNum, cnt
FROM slot_capacity
WHERE slotNum < 120
GROUP BY it, efs, src, wn, slotNum
;

DROP TABLE IF EXISTS avg_slot_capacity;
CREATE TABLE avg_slot_capacity 
AS
SELECT it, efs, src, avg(cnt) as avgCnt
FROM slot_capacity
GROUP BY it, efs, src;


DROP TABLE IF EXISTS avg_slot_capacity_first;
CREATE TABLE avg_slot_capacity_first 
AS
SELECT it, efs, src, avg(cnt) as avgCnt
FROM slot_capacity_first
GROUP BY it, efs, src;


--per node throughput increase
DROP TABLE IF EXISTS tpi;
CREATE TABLE tpi AS
select nofs.src as src, 
  fs.avgCnt/nofs.avgCnt as tpi,
  fs.avgCnt as fsTp,
  nofs.avgCnt as nofsTp
FROM avg_slot_capacity as nofs
JOIN avg_slot_capacity as fs
 ON nofs.src=fs.src
 AND nofs.efs=0
 AND fs.efs=1
;

DROP TABLE IF EXISTS avgDistance;
CREATE TABLE avgDistance AS
SELECT node, avg(hc) as avgDistance
FROM tests_vt
JOIN label ON tests_vt.it = label.it
JOIN rx
  on rx.it=label.it
AND rx.src=0
GROUP BY node;

--average throughput increase
SELECT avg(tpi)
FROM 
(
select nofs.src as src, 
  fs.avgCnt/nofs.avgCnt as tpi
FROM avg_slot_capacity_first as nofs
JOIN avg_slot_capacity_first as fs
 ON nofs.src=fs.src
 AND nofs.efs=0
 AND fs.efs=1
) x
;

-- tpi vs. distance
DROP TABLE IF EXISTS tpi_v_distance;
CREATE TABLE tpi_v_distance AS
select * from tpi 
JOIN avgDistance 
  on tpi.src=avgDistance.node;

-- network bytes/second, 12 byte payload: maxes out at 24/55 B/s.
-- 1 minute IPI is a total network load of 11.4 B/s: 
--   12 B/node/min * 57 nodes / 60 seconds
-- and with a 100 b payload, we support 202/460 B/s network capacity
SELECT efs, src, (12*avgCnt)/1.92 FROM avg_slot_capacity ;
SELECT efs, avg((12*avgCnt)/1.92) FROM avg_slot_capacity group by efs;
-- network bytes/second, 100 byte payload
SELECT efs, avg((100*avgCnt)/1.92) FROM avg_slot_capacity group by efs;
