DROP TABLE IF EXISTS txfTmp;
CREATE TEMPORARY TABLE txfTmp AS
SELECT * FROM delta
JOIN txf ON txf.bit = delta.bit AND delta.val=1
ORDER BY rn;

DROP TABLE IF EXISTS txvTmp;
CREATE TEMPORARY TABLE txvTmp AS
SELECT * FROM delta
JOIN txv ON txv.bit = delta.bit AND delta.val=1
ORDER BY rn;

DROP TABLE IF EXISTS txOffset;
CREATE TABLE txOffset AS
SELECT txvTmp.ts - txfTmp.ts as offset
FROM txfTmp 
JOIN txvTmp ON abs(txfTmp.ts - txvTmp.ts) < 1e-3;

SELECT * from txOffset;
