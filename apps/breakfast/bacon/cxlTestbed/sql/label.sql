DROP TABLE IF EXISTS label;
CREATE TABLE label AS
SELECT setup.it as it, 
  setup.ts as ts, 
  efs.val as efs, 
  mt.val as mt,
--  map.val as map,
  (map.val='maps/segmented/map.patches.9') as multitier,
  ppd.val as ppd,
  fps.val as fps,
  tpl.val as tpl
FROM setup 
JOIN setup as efs
  ON efs.node=setup.node
  AND efs.it =setup.it
  AND efs.key='efs'
JOIN setup as mt
  ON mt.node=setup.node
  AND mt.it=setup.it
  AND mt.key='mt'
JOIN setup as map
  ON map.node=setup.node
  AND map.it=setup.it
  AND map.key='map'
JOIN setup as ppd
  ON ppd.node=setup.node
  AND ppd.it=setup.it
  AND ppd.key='ppd'
JOIN setup as fps
  ON fps.node=setup.node
  AND fps.it=setup.it
  AND fps.key='fps'
JOIN setup as tpl
  ON tpl.node=setup.node
  AND tpl.it=setup.it
  AND tpl.key='tpl'
WHERE setup.node=0 and setup.key='installTS';
