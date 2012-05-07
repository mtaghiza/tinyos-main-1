.mode csv
SELECT 
  a.src as src, 
  a.dest as dest, 
  a.prr as src_to_dest, 
  coalesce(b.prr,0) as dest_to_src 
  FROM final_prr_no_startup a left JOIN final_prr_no_startup b
  ON a.src == b.dest and a.dest == b.src 
  WHERE a.src ==0;
