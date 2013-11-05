--identify the tests for segmentation v. flat 
DROP TABLE IF EXISTS tests_seg;
CREATE TABLE tests_seg AS
SELECT label.it as it, multitier, ppd, fps
FROM label
JOIN prr_summary
ON label.it=prr_summary.it
WHERE fps=60 and (efs=1 and ppd in (0, 75)) OR (efs=0 and ppd=0)
AND min(lr, rl) > 0.98;

--duty cycle: get active time for download by node, and mark each with
-- the type of download (subnetwork or router)
DROP TABLE IF EXISTS role_active;
CREATE TABLE role_active
AS
SELECT tests_seg.*, 
  wakeup_info.node,
  role.val as role, 
  wakeup_info.channel,
  wakeup_info.wn,
  ((multitier=1 and channel!=0) OR (multitier=0)) as subnet,
  activeS
FROM tests_seg
JOIN setup as role
  ON tests_seg.it=role.it
  AND role.key='role'
JOIN wakeup_info
  ON wakeup_info.it=tests_seg.it
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
  FROM role_active
  WHERE subnet=0
  GROUP BY it, node
) a join role_active b
ON a.it=b.it and a.node=b.node
and b.wn=a.wn;

DELETE 
FROM role_active
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
  FROM role_active
  GROUP BY it, node
) a join role_active b
ON a.it=b.it and a.node=b.node
and b.wn=a.wn;

DELETE FROM role_active
WHERE rowid in (
  SELECT delRowId
  FROM lastWakeup
);

--aggregate by setup type and node
DROP TABLE IF EXISTS seg_dc_agg;
CREATE TABLE seg_dc_agg AS
SELECT multitier, ppd, fps, node, subnet, avg(activeS) as activeS
FROM role_active
GROUP BY multitier, ppd, fps, node, subnet;

--and join the tests up by node, distinguishing by role
DROP TABLE IF EXISTS seg_dc_compare;
CREATE TABLE seg_dc_compare AS
SELECT mt.ppd as ppd,
  mt.fps as fps,
  mt.node as node,
  mt.subnet as subnet,
  mt.activeS as mtActive,
  flat.activeS as flatActive
FROM seg_dc_agg mt
JOIN seg_dc_agg flat
  ON flat.node=mt.node
  AND flat.ppd=mt.ppd
  AND flat.fps=mt.fps
WHERE flat.multitier=0 AND mt.multitier=1;

--sum up the master/slave contributions at router to get a single
-- number for each router. min(flatActive) is OK, because flatActive
-- is the same value for each of the master/slave entries
DROP TABLE IF EXISTS seg_dc_compare_agg;
CREATE TABLE seg_dc_compare_agg AS
SELECT ppd, fps, node, min(subnet) as leafOnly, sum(mtActive) as mtActive, min(flatActive) as flatActive
FROM seg_dc_compare
GROUP BY ppd, fps, node;

-- get the distance of each leaf from its master
DROP TABLE IF EXISTS leafDistance;
CREATE TABLE leafDistance AS
select src as master, node as slave, 
 avg(hc) as distance
FROM rx 
WHERE it in 
(
  SELECT it from tests_seg
  WHERE multitier=1) 
AND
src in (
  select node from seg_dc_compare_agg where leafOnly=0) 
and node not in (
  select node from seg_dc_compare_agg where leafOnly=0) 
GROUP BY src, node;

-- get the distance of each router from node 0 (root)
DROP TABLE IF EXISTS routerDistance;
CREATE TABLE routerDistance AS
select src as master, node as slave, 
 avg(hc) as distance
FROM rx 
WHERE it in 
(
  SELECT it from tests_seg
  WHERE multitier=1) 
AND src = 0  
and node in (
  select node from seg_dc_compare_agg where leafOnly=0) 
GROUP BY src, node;

--distance from root in flat network
DROP TABLE IF EXISTS flatDistance;
CREATE TABLE flatDistance AS
SELECT src as master, node as slave, avg(hc) as distance
FROM rx
JOIN tests_seg
ON rx.it=tests_seg.it
WHERE tests_seg.multitier=0
AND src=0
GROUP BY src, node;

--Leaf data
DROP TABLE IF EXISTS seg_leaf_final;
CREATE TABLE seg_leaf_final AS
select dc.ppd, dc.fps, dc.node, 
  flatDistance.distance as flat, 
  leafDistance.distance as leaf ,
  dc.mtActive as mtActive,
  dc.flatActive as flatActive,
  dc.mtActive/dc.flatActive as mtFrac,
  flatDistance.distance/leafDistance.distance as shorten,
  patchSize.patchSize 
FROM seg_dc_compare as dc 
JOIN flatDistance 
  on dc.node=flatDistance.slave 
JOIN leafDistance 
  on dc.node=leafDistance.slave 
JOIN (
  SELECT master, count(*) as patchSize
  FROM leafDistance
  GROUP BY master
) patchSize ON patchSize.master=leafDistance.master
order by ppd, mtFrac;

--Router data
DROP TABLE IF EXISTS seg_router_final;
CREATE TABLE seg_router_final AS
select dc.ppd, dc.fps, dc.node, 
  flatDistance.distance as flat, 
  routerDistance.distance as router,
  dc.mtActive as mtActive,
  dc.flatActive as flatActive,
  dc.mtActive/dc.flatActive as mtFrac,
  flatDistance.distance/routerDistance.distance as shorten,
  patchSize.patchSize 
FROM seg_dc_compare_agg as dc 
JOIN flatDistance 
  on dc.node=flatDistance.slave 
JOIN routerDistance 
  on dc.node=routerDistance.slave 
JOIN (
  SELECT master, count(*) as patchSize
  FROM leafDistance
  GROUP BY master
) patchSize ON patchSize.master=dc.node
order by ppd, fps, mtFrac;

DROP TABLE IF EXISTS seg_dc_final;
CREATE TABLE seg_dc_final AS
SELECT ppd, node, mtFrac, mtActive, flatActive, shorten, patchSize, 1 as router 
FROM seg_router_final 
UNION 
select ppd, node, mtFrac, mtActive, flatActive, shorten, patchSize, 0 as router 
FROM seg_leaf_final;
