DROP TABLE IF EXISTS tests_vprr;
CREATE TABLE tests_vprr AS 
SELECT label.it as it
FROM label 
JOIN prr_summary
ON label.it=prr_summary.it
WHERE multitier=0 and ppd=50 and fps=60 and tpl=12
AND min(lr, rl) > 0.98
;

--leaf -> root: average: 99.57%/99.69% on first run
SELECT label.efs, dest, avg(prr) as avgPrr 
FROM tests_vprr 
JOIN label on label.it=tests_vprr.it
JOIN prr
  ON prr.it=label.it
WHERE 
dest=0
AND src not in(42)
GROUP BY label.efs;

--leaf -> root: individual
SELECT label.efs, prr.src, prr.dest, prr 
FROM tests_vprr 
JOIN label on label.it=tests_vprr.it
JOIN prr
  ON prr.it=label.it
WHERE 
dest=0
AND src not in (42)
;

--root -> leaf: average: 96.4%/97.6%. hmmm
SELECT label.efs, prr.src, avg(prr) as avgPrr 
FROM tests_vprr 
JOIN label on label.it=tests_vprr.it
JOIN prr
  ON prr.it=label.it
WHERE 
src=0
AND dest not in (42)
GROUP BY label.efs, prr.src;

--root -> leaf: individual
-- looks like 2,3,4,5 are not very well-connected in this direction.
-- 12 is hit and miss
SELECT label.efs, prr.dest, prr 
FROM tests_vprr 
JOIN label on label.it=tests_vprr.it
JOIN prr
  ON prr.it=label.it
WHERE 
src=0
AND dest not in (42)
;

DROP TABLE IF EXISTS validation_prr;
CREATE TABLE validation_prr AS
SELECT label.efs, prr.src, prr.dest, prr
FROM tests_vprr
JOIN label on label.it=tests_vprr.it
JOIN prr 
  ON prr.it = label.it
WHERE src=0 or dest=0
;

select "SUMMARY";
select efs, src, avg(prr) from validation_prr where src=0 
and dest not in (42) group by
efs;
select efs, dest, avg(prr) from validation_prr where dest=0 and src
not in (42) group by
efs;
