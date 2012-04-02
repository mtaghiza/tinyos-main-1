.mode csv
SELECT
 la.node,
 la.activeFrac,
 lca.avgCurrent
 FROM LAST_ACTIVE la
 JOIN LAST_CURRENT_AVG lca
 ON la.node == lca.node;
