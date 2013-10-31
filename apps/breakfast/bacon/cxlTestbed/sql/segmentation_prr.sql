-- PRR to root
DROP TABLE IF EXISTS prrToRootFlat;
CREATE TABLE prrToRootFlat AS
SELECT src, dest, (1.0*sum(rxc))/sum(txc) as prr
FROM tests_seg
JOIN prr
  ON tests_seg.it=prr.it
JOIN flatDistance 
  ON flatDistance.slave = prr.src
WHERE prr.dest in (
  SELECT master from flatDistance
)
AND multitier=0
-- AND prr.src not in (
--   SELECT master
--   FROM leafDistance)
GROUP BY multitier, src, dest
;

-- PRR to router
DROP TABLE IF EXISTS prrToRouter;
CREATE TABLE prrToRouter AS
SELECT src, dest, (1.0*sum(rxc))/sum(txc) as prr
FROM tests_seg
JOIN prr
  ON tests_seg.it=prr.it
JOIN leafDistance 
  ON leafDistance.slave = prr.src
WHERE prr.dest in (
  SELECT master from leafDistance
)
AND multitier=1
-- AND prr.src not in (
--   SELECT master
--   FROM leafDistance)
GROUP BY multitier, src, dest
;

-- PRR from router to root
DROP TABLE IF EXISTS prrToRootMt;
CREATE TABLE prrToRootMt AS
SELECT src, dest, (1.0*sum(rxc))/sum(txc) as prr
FROM tests_seg
JOIN prr
  ON tests_seg.it=prr.it
JOIN routerDistance 
  ON routerDistance.slave = prr.src
WHERE prr.dest in (
  SELECT master from routerDistance
)
AND multitier=1
-- AND prr.src not in (
--   SELECT master
--   FROM leafDistance)
GROUP BY multitier, src, dest
;

DROP TABLE IF EXISTS seg_prr_final;
CREATE TABLE seg_prr_final AS
SELECT patch.src, rmt.prr*patch.prr as tunneledPrr,
  flat.prr as flatPrr
FROM prrToRootMt as rmt
JOIN prrToRouter as patch
  ON rmt.src=patch.dest
JOIN prrToRootFlat as flat
  ON patch.src=flat.src
ORDER BY flatPrr
;

--comparing tunneled v. non-tunneled. slightly hurts a few,
-- slightly helps a few
SELECT src, tunneledPrr, tunneledPrr-flatPrr 
FROM seg_prr_final 
ORDER by tunneledPrr-flatPrr;
