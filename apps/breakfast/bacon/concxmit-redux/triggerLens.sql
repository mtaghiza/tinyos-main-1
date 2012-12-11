DROP TABLE IF EXISTS triggerTmp;
CREATE TEMPORARY TABLE triggerTmp AS
SELECT * FROM delta
JOIN trigger ON delta.bit = trigger.bit 
ORDER BY rn;

DROP TABLE IF EXISTS triggerLen;
CREATE TABLE triggerLen as 
SELECT r.ts - l.ts as len
FROM triggerTmp l 
JOIN triggerTmp r ON l.rowid+1 = r.rowid
WHERE r.val=1;

SELECT * FROM triggerLen;
