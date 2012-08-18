.mode csv

DROP TABLE IF EXISTS BD_LINKS;
CREATE TEMPORARY TABLE BD_LINKS
AS 
  SELECT distinct src, dest FROM rx_all
  INTERSECT
  SELECT distinct dest, src FROM rx_all;

DELETE FROM BD_LINKS WHERE src <> 0;

-- flood depth
-- r -> l depth
SELECT
  rx_all.src as root, 
  rx_all.dest as leaf, 
  0 as lr,
  rx_all.sn,
  rx_all.depth
FROM BD_LINKS
JOIN rx_all
  ON rx_all.src= bd_links.src and rx_all.dest = bd_links.dest
JOIN tx_all 
  ON rx_all.src=tx_all.src
    AND rx_all.sn = tx_all.sn
WHERE rx_all.src=0
  AND tx_all.np = 1
  AND tx_all.pr = 0
ORDER by rx_all.dest;

-- l -> r depth
.header OFF
SELECT
  rx_all.dest as root, 
  rx_all.src as leaf, 
  1 as lr,
  rx_all.sn,
  rx_all.depth
FROM BD_LINKS
JOIN rx_all
  ON rx_all.src = bd_links.dest and rx_all.dest = bd_links.src
JOIN tx_all 
  ON rx_all.src=tx_all.src
    AND rx_all.sn = tx_all.sn
WHERE rx_all.dest = 0
  AND tx_all.np = 1
  AND tx_all.pr = 0
ORDER by rx_all.dest;
