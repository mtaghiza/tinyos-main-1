---------------------------------------
-- Associate sensor samples with timing information and type/id.

-- Join toast_sample with toast_connection on
-- reboot_counter/node_id/toast_id
DROP TABLE IF EXISTS ss0;
CREATE TEMPORARY TABLE ss0 AS
SELECT ts.node_id, ts.reboot_counter, ts.cookie as sample_cookie,
  tc.cookie as connection_cookie
FROM toast_sample ts
  JOIN toast_connection tc
ON ts.node_id = tc.node_id 
  AND ts.reboot_counter = tc.reboot_counter
  AND ts.toast_id = tc.toast_id 
  AND tc.cookie < ts.cookie;
-- This may leave duplicate entries for the case where the same toast 
-- was connected more than once to a single bacon on the same reboot
-- counter.

-- Associate each toast sample with the
-- highest-cookie'd preceding connection record from this reboot
-- counter.
DROP TABLE IF EXISTS ss1;
CREATE TEMPORARY TABLE ss1 AS
SELECT node_id, sample_cookie, 
  max(connection_cookie) as connection_cookie
FROM ss0
GROUP BY node_id, sample_cookie;

-- join sensor_samples with their timing/ID information
DROP TABLE IF EXISTS sensor_sample_flat;
CREATE TABLE sensor_sample_flat AS
SELECT sc.sensor_type, sc.sensor_id, 
  ts.node_id, ts.reboot_counter, ts.base_time,  
  ss.sample
FROM sensor_sample ss 
  JOIN toast_sample ts 
    ON ss.node_id = ts.node_id AND ss.cookie = ts.cookie
  JOIN ss1 
    ON ss.node_id = ss1.node_id AND ss.cookie=ss1.sample_cookie
  JOIN toast_connection tc
    ON ss1.connection_cookie = tc.cookie AND ss1.node_id = tc.node_id
  JOIN sensor_connection sc
    ON sc.cookie = tc.cookie AND
    sc.channel_number = ss.channel_number
;

---------------------------------------
-- associate bacon samples with barcodes, similar approach to above
DROP TABLE IF EXISTS bs0;
CREATE TEMPORARY TABLE bs0 AS
SELECT bsa.node_id, bsa.cookie as sample_cookie, bse.cookie as settings_cookie
FROM bacon_sample as bsa
JOIN bacon_settings as bse 
  ON bsa.reboot_counter=bse.rc AND bse.cookie < bsa.cookie
  AND bsa.node_id = bse.node_id
WHERE bse.barcode_id != '';

-- dump the extras
DROP TABLE IF EXISTS bs1;
CREATE TEMPORARY TABLE bs1 AS
SELECT node_id, sample_cookie, max(settings_cookie) as settings_cookie
FROM bs0
GROUP BY node_id, sample_cookie;

DROP TABLE IF EXISTS bacon_sample_flat;
CREATE TABLE bacon_sample_flat AS
SELECT bsa.*, bse.barcode_id
FROM bacon_sample bsa
JOIN bs1 
  ON bsa.cookie = bs1.sample_cookie AND bsa.node_id = bs1.node_id
JOIN bacon_settings bse
  ON bse.cookie = bs1.settings_cookie AND bse.node_id =
  bs1.node_id
;

---- apply fits and convert to volts.

DROP TABLE IF EXISTS bacon_sample_final;
CREATE TABLE bacon_sample_final AS
SELECT bsf.barcode_id, bsf.node_id, bsf.cookie,  
  (base_time*beta + alpha) as ts, 
  2.0*(battery/4096.0)*2.5 as batteryVoltage,
  (light/4096.0)*2.5 as lightVoltage,
  (thermistor/4096.0)*2.5 as thermistorVoltage
FROM bacon_sample_flat bsf
JOIN fits 
  ON fits.node1=bsf.node_id AND fits.rc1=bsf.reboot_counter
     AND fits.node2 is NULL and fits.rc2 is NULL;

DROP TABLE IF EXISTS sensor_sample_final;
CREATE TABLE sensor_sample_final AS
SELECT ssf.sensor_type, ssf.sensor_id, 
  (base_time*beta + alpha) as ts,
  (sample/4096.0)*2.5 as voltage
FROM sensor_sample_flat ssf
JOIN fits 
  ON fits.node1=ssf.node_id AND fits.rc1=ssf.reboot_counter
     AND fits.node2 is NULL AND fits.rc2 is NULL;

