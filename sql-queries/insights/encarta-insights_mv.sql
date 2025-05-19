CREATE MATERIALIZED VIEW sbx_uat_insights.mv_sku_unit_summary
TO sbx_uat_insights.sku_unit_summary
AS
SELECT 
    suv.id,
    suv.code,
    SUM(suv.l1units) AS ibc,
    SUM(suv.l2units) AS casecount,
    SUM(suv.l3units) AS palletcount
FROM
    (SELECT 
        su.id,
        su.code,
        CASE WHEN su.hierarchy='L1' THEN units ELSE 0 END AS l1units,
        CASE WHEN su.hierarchy='L2' THEN units ELSE 0 END AS l2units,
        CASE WHEN su.hierarchy='L3' THEN units ELSE 0 END AS l3units
     FROM
        (SELECT 
            s.id,
            s.code,
            u.hierarchy,
            u.units 
         FROM sbx_uat_encarta.skus s
         Left JOIN sbx_uat_encarta.uoms u ON s.id=u.sku_id
        ) AS su
    ) suv
GROUP BY suv.id, suv.code;
