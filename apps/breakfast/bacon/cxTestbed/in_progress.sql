DROP TABLE IF EXISTS FINAL_PRR;
CREATE TABLE FINAL_PRR AS 
  SELECT 
    src, 
    dest, 
    avg(received) as prr
  FROM conn 
  WHERE src ==0 or dest == 0
  GROUP BY src, dest
  ORDER BY src, dest;

