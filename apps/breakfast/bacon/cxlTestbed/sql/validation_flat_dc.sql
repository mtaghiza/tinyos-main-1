DROP TABLE IF EXISTS tests_vfdc;
CREATE TABLE tests_vfdc AS 
SELECT label.it as it,efs
FROM label 
JOIN prr_summary
ON label.it=prr_summary.it
WHERE multitier=0 and ppd=50 and fps=60 and tpl=12
AND min(lr, rl) > 0.98;


--OK, well this gives us duty cycle numbers for each wakeup
--wn < 3: discard partial downloads
DROP TABLE IF EXISTS flat_active_indiv;
CREATE TABLE flat_active_indiv as
SELECT efs, node, activeS, activeS/(50.0*60.0) as dc 
FROM active_period 
JOIN tests_vfdc as tests
ON active_period.it=tests.it
WHERE wn < 3
;

select efs, avg(dc) from flat_active_indiv
GROUP BY efs;
