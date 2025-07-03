-- Population script for SKU classifications table
INSERT INTO `sbx-uat.encarta.public.skus_classifications_agg`
SELECT c.sku_id,
    CAST(JSON_OBJECTAGG(KEY c.type VALUE c.`value`) AS STRING) AS classifications
FROM `sbx-uat.encarta.public.classifications` c
GROUP BY c.sku_id;
