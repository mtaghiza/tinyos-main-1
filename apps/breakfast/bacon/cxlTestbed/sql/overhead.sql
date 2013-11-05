DROP TABLE IF EXISTS tests_overhead;
CREATE TABLE tests_overhead AS
SELECT label.it as it, ppd, fps, multitier
FROM label
JOIN prr_summary
ON label.it=prr_summary.it
WHERE multitier=0
AND (ppd=75 and tpl=100 and efs=1) or (ppd=0)
AND min(lr, rl) > 0.98
;

DROP TABLE IF EXISTS overhead_active;
CREATE TABLE overhead_active
AS
SELECT tests_overhead.*, 
  wakeup_info.node,
  role.val as role, 
  wakeup_info.channel,
  wakeup_info.wn,
  ((multitier=1 and channel!=0) OR (multitier=0)) as subnet,
  activeS
FROM tests_overhead
JOIN setup as role
  ON tests_overhead.it=role.it
  AND role.key='role'
JOIN wakeup_info
  ON wakeup_info.it=tests_overhead.it
  AND role.node=wakeup_info.node
JOIN active_period
  ON active_period.it=wakeup_info.it
  AND active_period.node=wakeup_info.node
  AND active_period.wn=wakeup_info.wn
;

--delete first router wakeup (bootstrap) 
DROP TABLE IF EXISTS firstRouterWakeup;
CREATE TEMPORARY TABLE firstRouterWakeup
AS 
SELECT b.rowid as delRowId, a.it, a.node, a.wn
FROM 
( 
  SELECT it, node, min(wn) as wn
  FROM overhead_active
  WHERE subnet=0
  GROUP BY it, node
) a join overhead_active b
ON a.it=b.it and a.node=b.node
and b.wn=a.wn;

DELETE 
FROM overhead_active
WHERE rowid in
(
  SELECT delRowid
  FROM firstRouterWakeup
);

-- Delete last wakeup for each node (might be cut off)
DROP TABLE IF EXISTS lastWakeup;
CREATE TEMPORARY TABLE lastWakeup
AS 
SELECT b.rowid as delRowId, a.it, a.node, a.wn
FROM 
( 
  SELECT it, node, max(wn) as wn
  FROM overhead_active
  GROUP BY it, node
) a join overhead_active b
ON a.it=b.it and a.node=b.node
and b.wn=a.wn;

DELETE FROM overhead_active
WHERE rowid in (
  SELECT delRowId
  FROM lastWakeup
);

DROP TABLE IF EXISTS overhead_dc_agg;
CREATE TABLE overhead_dc_agg AS
select ppd, fps, node, subnet, 
  avg(activeS) as activeS
FROM overhead_active 
GROUP BY ppd, fps, node, subnet;

--yeah, i think that this data is going to be impossible to read with
-- the segmentation applied. Should run this series on a flat network.
