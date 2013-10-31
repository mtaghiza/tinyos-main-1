-- remove the wakeup slot and the idle duty cycle
DROP TABLE IF EXISTS ACTIVE_PERIOD;
CREATE TABLE ACTIVE_PERIOD as
SELECT it, node, wn, sum(activeS) as activeS
FROM active
WHERE slotNum >=1
GROUP BY it, node, wn;

-- join wakeup info to slots so we can differentiate between router
-- and subnet downloads
DROP TABLE IF EXISTS WAKEUP_INFO;
CREATE TABLE WAKEUP_INFO AS
SELECT distinct wakeup.it, wakeup.ts, wakeup.node, wakeup.channel, active.wn
FROM wakeup
JOIN active 
ON wakeup.it=active.it AND wakeup.node=active.node
AND active.role in (4, 5) AND active.ts -wakeup.ts between 0.0 and 10.0
;

